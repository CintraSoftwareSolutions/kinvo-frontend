import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/server_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/flow_widgets.dart';
import '../../../modes/presentation/mode_presentation.dart';
import '../controllers/interests_step_controller.dart';
import '../controllers/onboarding_controller.dart';
import '../widgets/onboarding_step_layout.dart';

class InterestsStep extends ConsumerWidget {
  const InterestsStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interests =
        ref.watch(
          onboardingControllerProvider.select(
            (state) => state.value?.config.interests,
          ),
        ) ??
        const <InterestOption>[];
    final form = ref.watch(interestsStepControllerProvider);
    final controller = ref.read(interestsStepControllerProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return OnboardingStepLayout(
      step: OnboardingStep.interests,
      title: 'Your interests',
      subtitle:
          "Pick what you're into, so people can see what you have in common.",
      error: form.error,
      actionLabel: 'Continue',
      actionLoading: form.isSubmitting,
      onAction: () => unawaited(controller.submit()),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              '${form.selected.length} of ${form.maxInterests} chosen',
              style: textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          for (final (category, options) in groupInterestsByCategory(
            interests,
          )) ...[
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(
                interestCategoryLabel(category),
                style: textTheme.titleLarge?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final interest in options)
                  OptionChip(
                    label: interest.label,
                    selected: form.selected.contains(interest.slug),
                    onTap: () => controller.toggle(interest.slug),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
