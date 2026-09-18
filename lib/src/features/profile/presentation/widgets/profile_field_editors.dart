import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/forms/form_errors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/flow_widgets.dart';
import '../../domain/profile_fields.dart';
import '../../domain/profile_rules.dart';
import '../controllers/profile_controllers.dart';

/// Opens the editor for one detail on the profile, which saves it. [current]
/// is what the profile holds now, and [options] the answers the server
/// accepts for details that are picked from a list.
Future<void> showProfileFieldEditor(
  BuildContext context, {
  required ProfileField field,
  required Object? current,
  List<String> options = const [],
  int bioMaxLength = 500,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => switch (field) {
      ProfileField.heightCm => _HeightEditor(current: current as int?),
      _ when field.hasOptions => _OptionEditor(
        field: field,
        current: current as String?,
        options: options,
      ),
      _ => _TextEditor(
        field: field,
        current: current as String?,
        maxLength:
            ProfileRules.maxLengthOf(field, bioMaxLength: bioMaxLength) ??
            bioMaxLength,
        bioMaxLength: bioMaxLength,
      ),
    },
  );
}

/// The frame every editor sits in: a handle, a title, and whatever it edits.
class _EditorFrame extends StatelessWidget {
  const _EditorFrame({
    required this.title,
    required this.child,
    this.description,
  });

  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (description case final description?) ...[
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// Saves [value] as [field] on the profile. Returns why it failed, or `null`
/// once it's saved.
Future<String?> _save(WidgetRef ref, ProfileField field, Object? value) async {
  try {
    await ref.read(ownProfileProvider.notifier).updateDetails({field: value});
    return null;
  } on ApiException catch (error) {
    return saveFailureMessage(error, field: field.apiName);
  }
}

class _TextEditor extends ConsumerStatefulWidget {
  const _TextEditor({
    required this.field,
    required this.current,
    required this.maxLength,
    required this.bioMaxLength,
  });

  final ProfileField field;
  final String? current;
  final int maxLength;
  final int bioMaxLength;

  @override
  ConsumerState<_TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends ConsumerState<_TextEditor> {
  late final _text = TextEditingController(text: widget.current ?? '');
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _multiline => widget.field == ProfileField.bio;

  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    return _EditorFrame(
      title: switch (field) {
        ProfileField.displayName => 'Your name',
        ProfileField.bio => 'Your bio',
        _ => field.label,
      },
      description: switch (field) {
        ProfileField.displayName => 'The name people see on your profile.',
        ProfileField.bio =>
          'A few lines about you. 20 characters or more counts towards a '
              'complete profile.',
        ProfileField.city => 'The town or city people see on your profile.',
        _ => 'Leave it empty to take it off your profile.',
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _text,
            autofocus: true,
            enabled: !_saving,
            maxLength: widget.maxLength,
            minLines: _multiline ? 4 : 1,
            maxLines: _multiline ? 8 : 1,
            textCapitalization: field == ProfileField.bio
                ? TextCapitalization.sentences
                : TextCapitalization.words,
            textInputAction: _multiline
                ? TextInputAction.newline
                : TextInputAction.done,
            onSubmitted: _multiline ? null : (_) => _submit(),
            decoration: InputDecoration(
              labelText: field.label,
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryActionButton(
            label: 'Save',
            borderRadius: 999,
            loading: _saving,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_saving) return;
    final text = _text.text.trim();
    final invalid = ProfileRules.textError(
      widget.field,
      text,
      bioMaxLength: widget.bioMaxLength,
    );
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    if (text == (widget.current ?? '')) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await _save(ref, widget.field, text.isEmpty ? null : text);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }
}

class _OptionEditor extends ConsumerStatefulWidget {
  const _OptionEditor({
    required this.field,
    required this.current,
    required this.options,
  });

  final ProfileField field;
  final String? current;
  final List<String> options;

  @override
  ConsumerState<_OptionEditor> createState() => _OptionEditorState();
}

class _OptionEditorState extends ConsumerState<_OptionEditor> {
  /// The answer being saved, or the empty string while clearing it.
  String? _saving;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    final options = widget.options;

    return _EditorFrame(
      title: field.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (options.isEmpty)
            const Text(
              "These answers couldn't be loaded. Please try again later.",
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          RadioGroup<String>(
            groupValue: widget.current,
            onChanged: (value) {
              if (value != null) _choose(value);
            },
            child: Column(
              children: [
                for (final option in options)
                  RadioListTile<String>(
                    value: option,
                    enabled: _saving == null,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.purple,
                    title: Text(profileOptionLabel(field, option)),
                    secondary: _saving == option
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                  ),
              ],
            ),
          ),
          if (widget.current != null) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _saving == null ? () => _choose(null) : null,
              icon: _saving == ''
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.remove_circle_outline_rounded),
              label: const Text('Take it off my profile'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
            ),
          ],
          if (_error case final error?) ...[
            const SizedBox(height: 8),
            FormErrorBanner(message: error),
          ],
        ],
      ),
    );
  }

  Future<void> _choose(String? value) async {
    if (_saving != null) return;
    if (value == widget.current) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = value ?? '';
      _error = null;
    });
    final error = await _save(ref, widget.field, value);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = null;
        _error = error;
      });
    }
  }
}

class _HeightEditor extends ConsumerStatefulWidget {
  const _HeightEditor({required this.current});

  final int? current;

  @override
  ConsumerState<_HeightEditor> createState() => _HeightEditorState();
}

class _HeightEditorState extends ConsumerState<_HeightEditor> {
  /// Where the slider starts for a profile with no height yet.
  static const _startingHeight = 170;

  late int _height = (widget.current ?? _startingHeight).clamp(
    ProfileRules.minHeightCm,
    ProfileRules.maxHeightCm,
  );

  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return _EditorFrame(
      title: 'Height',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              heightLabel(_height),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Slider(
            value: _height.toDouble(),
            min: ProfileRules.minHeightCm.toDouble(),
            max: ProfileRules.maxHeightCm.toDouble(),
            divisions: ProfileRules.maxHeightCm - ProfileRules.minHeightCm,
            activeColor: AppColors.purple,
            label: heightLabel(_height),
            semanticFormatterCallback: (value) => heightLabel(value.round()),
            onChanged: _saving
                ? null
                : (value) => setState(() => _height = value.round()),
          ),
          if (_error case final error?) ...[
            FormErrorBanner(message: error),
            const SizedBox(height: 8),
          ],
          PrimaryActionButton(
            label: 'Save',
            borderRadius: 999,
            loading: _saving,
            onPressed: () => _saveHeight(_height),
          ),
          if (widget.current != null)
            TextButton(
              onPressed: _saving ? null : () => _saveHeight(null),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              child: const Text('Take it off my profile'),
            ),
        ],
      ),
    );
  }

  Future<void> _saveHeight(int? height) async {
    if (_saving) return;
    if (height == widget.current) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await _save(ref, ProfileField.heightCm, height);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }
}
