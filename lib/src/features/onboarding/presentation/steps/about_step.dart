import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/widgets/flow_widgets.dart';
import '../../../auth/presentation/date_of_birth_picker.dart';
import '../controllers/about_step_controller.dart';
import '../controllers/onboarding_controller.dart';
import '../widgets/onboarding_step_layout.dart';

class AboutStep extends ConsumerWidget {
  const AboutStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(aboutStepControllerProvider);
    final controller = ref.read(aboutStepControllerProvider.notifier);
    final editable = !form.isSubmitting;
    final dateOfBirth = form.dateOfBirth;

    return OnboardingStepLayout(
      step: OnboardingStep.about,
      title: 'About you',
      subtitle: "This is how you'll appear to the people you meet on Kinvo.",
      error: form.formError,
      actionLabel: 'Continue',
      actionLoading: form.isSubmitting,
      onAction: () {
        FocusScope.of(context).unfocus();
        unawaited(controller.submit());
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppInputCard(
            label: 'NAME',
            value: form.displayName,
            assetName: AppAssets.user,
            onChanged: controller.updateDisplayName,
            errorText: form.errors[AboutField.displayName],
            enabled: editable,
            autofillHints: const [AutofillHints.name],
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 8),
          AppInputCard(
            label: 'BIO',
            value: form.bio,
            onChanged: controller.updateBio,
            errorText: form.errors[AboutField.bio],
            enabled: editable,
            hintText: "What you're into, and what you're looking for.",
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            minLines: 3,
            maxLines: 6,
          ),
          const SizedBox(height: 6),
          Text(
            '${form.bio.trim().length} / ${form.bioMaxLength}',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 11,
              color: form.bio.trim().length > form.bioMaxLength
                  ? AppColors.danger
                  : AppColors.textMuted,
            ),
          ),
          if (form.needsDateOfBirth) ...[
            const SizedBox(height: 8),
            AppPickerCard(
              label: 'DATE OF BIRTH',
              value: dateOfBirth == null
                  ? null
                  : formatDateOfBirth(context, dateOfBirth),
              placeholder: 'Select your date of birth',
              icon: Icons.cake_outlined,
              errorText: form.errors[AboutField.dateOfBirth],
              enabled: editable,
              onTap: () => unawaited(_pickDateOfBirth(context, ref)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickDateOfBirth(BuildContext context, WidgetRef ref) async {
    FocusScope.of(context).unfocus();
    final picked = await pickDateOfBirth(
      context,
      today: ref.read(clockProvider)(),
      initial: ref.read(aboutStepControllerProvider).dateOfBirth,
    );
    if (picked == null || !context.mounted) return;

    ref.read(aboutStepControllerProvider.notifier).updateDateOfBirth(picked);
  }
}
