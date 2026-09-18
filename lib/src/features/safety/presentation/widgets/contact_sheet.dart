import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/trusted_contact.dart';
import '../controllers/trusted_contacts_controllers.dart';

/// Adds a trusted contact, or changes or removes [existing].
Future<void> showContactSheet(
  BuildContext context, {
  TrustedContact? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ContactSheet(existing: existing),
  );
}

class _ContactSheet extends ConsumerStatefulWidget {
  const _ContactSheet({required this.existing});

  final TrustedContact? existing;

  @override
  ConsumerState<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends ConsumerState<_ContactSheet> {
  static final _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  // Owned by the sheet, so they last until the sheet has finished closing.
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _email = TextEditingController(text: widget.existing?.email);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  late final _relationship = TextEditingController(
    text: widget.existing?.relationship,
  );

  bool _saving = false;

  /// Whether the user has tried to save, after which problems show.
  bool _tried = false;

  /// The server's messages, by field.
  Map<String, String> _refused = const {};
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _relationship.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final problems = _tried ? _problems() : const <String, String>{};
    String? problem(String field) => problems[field] ?? _refused[field];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                existing == null ? 'Add a trusted contact' : 'Edit contact',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Kinvo emails them if you press the emergency button, or share "
                "a plan with them. They don't need the app.",
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              _field(
                _name,
                label: 'Name',
                error: problem('name'),
                capitalization: TextCapitalization.words,
                maxLength: 100,
              ),
              _field(
                _email,
                label: 'Email',
                error: problem('email'),
                keyboard: TextInputType.emailAddress,
                maxLength: 320,
              ),
              _field(
                _phone,
                label: 'Phone (optional)',
                error: problem('phone'),
                keyboard: TextInputType.phone,
                maxLength: 32,
              ),
              _field(
                _relationship,
                label: 'How you know them (optional)',
                error: problem('relationship'),
                capitalization: TextCapitalization.sentences,
                maxLength: 64,
              ),
              if (_error case final message?) ...[
                Text(
                  message,
                  style: const TextStyle(fontSize: 13, color: AppColors.danger),
                ),
                const SizedBox(height: 10),
              ],
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
              if (existing != null)
                TextButton(
                  onPressed: _saving ? null : () => _delete(existing),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  child: const Text('Remove contact'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller, {
    required String label,
    required String? error,
    required int maxLength,
    TextInputType? keyboard,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: TextField(
        controller: controller,
        enabled: !_saving,
        keyboardType: keyboard,
        textCapitalization: capitalization,
        maxLength: maxLength,
        onChanged: (_) {
          if (_tried) setState(() {});
        },
        decoration: InputDecoration(
          labelText: label,
          errorText: error,
          border: const OutlineInputBorder(),
          counterText: '',
        ),
      ),
    );
  }

  /// What stops the contact being saved, by field.
  Map<String, String> _problems() {
    final problems = <String, String>{};
    final name = _name.text.trim();
    final email = _email.text.trim();
    final phone = _phone.text.trim();

    if (name.isEmpty) problems['name'] = 'Add their name.';
    if (email.isNotEmpty && !_emailShape.hasMatch(email)) {
      problems['email'] = "That email address doesn't look right.";
    }
    if (phone.isNotEmpty && phone.length < 5) {
      problems['phone'] = "That phone number doesn't look right.";
    }
    if (email.isEmpty && phone.isEmpty) {
      problems['email'] = 'Add an email address, so Kinvo can alert them.';
    }
    return problems;
  }

  Future<void> _save() async {
    setState(() {
      _tried = true;
      _refused = const {};
      _error = null;
    });
    if (_problems().isNotEmpty) return;

    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ref
        .read(trustedContactsProvider.notifier)
        .save(
          ContactDetails(
            name: _name.text,
            email: _email.text,
            phone: _phone.text,
            relationship: _relationship.text,
          ),
          contactId: widget.existing?.id,
        );
    if (!mounted) return;
    setState(() => _saving = false);

    switch (outcome) {
      case ContactSaved(:final contact):
        navigator.pop();
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                contact.canBeAlerted
                    ? '${contact.name} is a trusted contact.'
                    : '${contact.name} is saved, but Kinvo can only alert '
                          'them once they have an email address.',
              ),
            ),
          );
      case ContactRefused(:final message, :final fieldErrors):
        setState(() {
          _refused = {
            for (final MapEntry(:key, :value) in fieldErrors.entries)
              if (value.isNotEmpty) key: value.first,
          };
          if (_refused.isEmpty) _error = message;
        });
    }
  }

  Future<void> _delete(TrustedContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Remove ${contact.name}?'),
        content: const Text("They won't be alerted any more."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final error = await ref
        .read(trustedContactsProvider.notifier)
        .delete(contact);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    navigator.pop();
  }
}
