import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/server_config.dart';
import '../../../../core/forms/form_errors.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/flow_widgets.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../domain/own_profile.dart';
import '../../domain/profile_fields.dart';
import '../../domain/profile_rules.dart';
import '../controllers/profile_controllers.dart';
import '../widgets/photo_editor_grid.dart';
import '../widgets/profile_field_editors.dart';
import '../widgets/prompt_editor_sheet.dart';
import '../widgets/public_profile_view.dart';

/// Changing the profile. Every change saves on its own, as it's made.
class ProfileEditScreen extends ConsumerWidget {
  const ProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(ownProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Edit profile',
              subtitle: 'Each change saves as soon as you make it',
              leading: HeaderBackButton(),
            ),
            Expanded(
              child: switch (profile) {
                AsyncValue(value: final profile?) => _EditForm(
                  profile: profile,
                ),
                AsyncValue(:final error?) => ListView(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                  children: [
                    LoadFailedCard(
                      message: saveFailureMessage(error),
                      onRetry: () => ref.invalidate(ownProfileProvider),
                    ),
                  ],
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EditForm extends ConsumerWidget {
  const _EditForm({required this.profile});

  final OwnProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(profileCatalogueProvider).value;
    final limits = catalogue?.limits;

    void edit(ProfileField field) {
      unawaited(
        showProfileFieldEditor(
          context,
          field: field,
          current: profile.valueOf(field),
          options: catalogue?.lifestyleOptions[field.apiName] ?? const [],
          bioMaxLength: limits?.bioMaxLength ?? ProfileRules.maxBioLength,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 32),
      children: [
        const SettingsSectionLabel('PHOTOS'),
        _Photos(name: profile.displayName),
        const SizedBox(height: 22),
        const SettingsSectionLabel('ABOUT YOU'),
        SettingsGroup(
          children: [
            for (final field in const [
              ProfileField.displayName,
              ProfileField.bio,
              ProfileField.jobTitle,
              ProfileField.organisation,
              ProfileField.education,
              ProfileField.heightCm,
              ProfileField.city,
            ])
              _FieldRow(
                field: field,
                value: profile.valueOf(field),
                onTap: () => edit(field),
              ),
          ],
        ),
        const SizedBox(height: 22),
        const SettingsSectionLabel('LIFESTYLE'),
        SettingsGroup(
          children: [
            for (final field in ProfileField.lifestyle)
              _FieldRow(
                field: field,
                value: profile.valueOf(field),
                onTap: () => edit(field),
              ),
          ],
        ),
        const SizedBox(height: 22),
        const SettingsSectionLabel('INTERESTS'),
        _Interests(profile: profile, maxInterests: limits?.maxInterests),
        const SizedBox(height: 22),
        const SettingsSectionLabel('PROMPTS'),
        _Prompts(
          profile: profile,
          questions: catalogue?.prompts ?? const [],
          maxPrompts: limits?.maxPrompts ?? ProfileLimits.defaultMaxPrompts,
        ),
      ],
    );
  }
}

class _Photos extends ConsumerWidget {
  const _Photos({required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final album = ref.watch(profilePhotosProvider);
    final edits = ref.watch(photoEditsProvider);

    return switch (album) {
      AsyncValue(value: final album?) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PhotoEditorGrid(album: album, edits: edits, name: name),
          const SizedBox(height: 10),
          const Text(
            'Hold a photo and drag it to change the order, or tap it for '
            'more. Your first photo is your main one.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          if (edits.error case final error?) ...[
            const SizedBox(height: 10),
            FormErrorBanner(message: error),
          ],
        ],
      ),
      AsyncValue(:final error?) => LoadFailedCard(
        message: saveFailureMessage(error),
        onRetry: () => ref.invalidate(profilePhotosProvider),
      ),
      _ => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

/// One detail and its current value, which opens its editor.
class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.field,
    required this.value,
    required this.onTap,
  });

  final ProfileField field;
  final Object? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shown = switch (value) {
      null => null,
      final int height when field == ProfileField.heightCm => heightLabel(
        height,
      ),
      final String option when field.hasOptions => profileOptionLabel(
        field,
        option,
      ),
      final String text when text.trim().isNotEmpty => text.trim(),
      _ => null,
    };

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(
        field.label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
      subtitle: Text(
        shown ?? 'Add',
        maxLines: field == ProfileField.bio ? 3 : 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: shown == null ? AppColors.purple : AppColors.textPrimary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _Interests extends StatelessWidget {
  const _Interests({required this.profile, required this.maxInterests});

  final OwnProfile profile;
  final int? maxInterests;

  @override
  Widget build(BuildContext context) {
    final interests = profile.interests;
    final count = maxInterests == null
        ? '${interests.length} chosen'
        : '${interests.length} of $maxInterests chosen';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (interests.isEmpty)
            const Text(
              'Add interests so people can see what you have in common.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final interest in interests)
                  InterestChip(label: interest.label),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  count,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.push(AppRoutes.profileInterests),
                style: TextButton.styleFrom(foregroundColor: AppColors.purple),
                child: Text(interests.isEmpty ? 'Add interests' : 'Change'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Prompts extends StatelessWidget {
  const _Prompts({
    required this.profile,
    required this.questions,
    required this.maxPrompts,
  });

  final OwnProfile profile;
  final List<PromptOption> questions;
  final int maxPrompts;

  @override
  Widget build(BuildContext context) {
    final answers = profile.prompts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final answer in answers) ...[
          Semantics(
            button: true,
            label: '${answer.question} ${answer.answer}',
            hint: 'Change or remove this prompt',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => unawaited(
                showPromptAnswerSheet(
                  context,
                  answers: answers,
                  editing: answer,
                ),
              ),
              behavior: HitTestBehavior.opaque,
              child: PromptCard(
                question: answer.question,
                answer: answer.answer,
                trailing: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (answers.length < maxPrompts)
          OutlineActionButton(
            label: answers.isEmpty
                ? 'Answer a prompt'
                : 'Add a prompt (${answers.length} of $maxPrompts)',
            onPressed: questions.isEmpty
                ? null
                : () => unawaited(
                    showAddPromptSheet(
                      context,
                      answers: answers,
                      questions: questions,
                    ),
                  ),
            foregroundColor: AppColors.purple,
            borderColor: AppColors.purple,
          )
        else
          Text(
            'You have answered $maxPrompts prompts, the most a profile '
            'shows. Tap one to change or remove it.',
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }
}
