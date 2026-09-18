import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/server_config.dart';
import '../../../../core/forms/form_errors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/flow_widgets.dart';
import '../../domain/own_profile.dart';
import '../../domain/profile_rules.dart';
import '../controllers/profile_controllers.dart';

/// Adds a prompt answer to the profile: first a question from [questions],
/// then the answer. Saves the profile's prompts with it at the end.
Future<void> showAddPromptSheet(
  BuildContext context, {
  required List<PromptAnswer> answers,
  required List<PromptOption> questions,
}) async {
  final answered = {for (final answer in answers) answer.slug};
  final available = [
    for (final question in questions)
      if (!answered.contains(question.slug)) question,
  ];
  final question = await showModalBottomSheet<PromptOption>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheet) => _QuestionPicker(questions: available),
  );
  if (question == null || !context.mounted) return;

  await showPromptAnswerSheet(
    context,
    answers: answers,
    editing: PromptAnswer(
      slug: question.slug,
      question: question.question,
      answer: '',
    ),
  );
}

/// Writes or changes the answer to [editing], one of [answers] or a new one,
/// and saves all of them. An answer already on the profile can be removed
/// here too.
Future<void> showPromptAnswerSheet(
  BuildContext context, {
  required List<PromptAnswer> answers,
  required PromptAnswer editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _AnswerEditor(answers: answers, editing: editing),
  );
}

class _QuestionPicker extends StatelessWidget {
  const _QuestionPicker({required this.questions});

  final List<PromptOption> questions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
          const Text(
            'Choose a prompt',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          if (questions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                "There are no more prompts to answer right now.",
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final question in questions)
                    ListTile(
                      onTap: () => Navigator.of(context).pop(question),
                      contentPadding: EdgeInsets.zero,
                      title: Text(question.question),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AnswerEditor extends ConsumerStatefulWidget {
  const _AnswerEditor({required this.answers, required this.editing});

  final List<PromptAnswer> answers;
  final PromptAnswer editing;

  @override
  ConsumerState<_AnswerEditor> createState() => _AnswerEditorState();
}

class _AnswerEditorState extends ConsumerState<_AnswerEditor> {
  late final _text = TextEditingController(text: widget.editing.answer);

  /// Whether saving or removing is under way.
  bool _saving = false;
  String? _error;

  bool get _isNew =>
      !widget.answers.any((answer) => answer.slug == widget.editing.slug);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

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
                widget.editing.question,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _text,
              autofocus: true,
              enabled: !_saving,
              maxLength: ProfileRules.maxPromptAnswerLength,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Your answer',
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
            if (!_isNew)
              TextButton(
                onPressed: _saving ? null : _remove,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Remove this prompt'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final answer = _text.text.trim();
    final invalid = ProfileRules.promptAnswerError(answer);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    final edited = widget.editing.withAnswer(answer);
    await _saveAll([
      if (_isNew) ...[
        ...widget.answers,
        edited,
      ] else
        for (final each in widget.answers)
          each.slug == edited.slug ? edited : each,
    ]);
  }

  Future<void> _remove() {
    return _saveAll([
      for (final each in widget.answers)
        if (each.slug != widget.editing.slug) each,
    ]);
  }

  Future<void> _saveAll(List<PromptAnswer> answers) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(ownProfileProvider.notifier).setPrompts(answers);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = saveFailureMessage(error, field: 'prompts');
      });
    }
  }
}
