import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/forms/form_errors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/flow_widgets.dart';
import '../../../../core/widgets/gradient_scaffold.dart';
import '../../../auth/presentation/log_out.dart';
import '../controllers/onboarding_controller.dart';
import '../steps/about_step.dart';
import '../steps/interests_step.dart';
import '../steps/location_step.dart';
import '../steps/modes_step.dart';
import '../steps/photos_step.dart';

/// Sets up a new account's profile, one step at a time. Where the account
/// already meets a step's requirements, onboarding resumes after it.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    final Widget body;
    if (onboarding.value case final state?) {
      body = PopScope(
        // The system back gesture returns to the previous step.
        canPop: state.step.isFirst,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) controller.back();
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KeyedSubtree(
            key: ValueKey(state.step),
            child: switch (state.step) {
              OnboardingStep.about => const AboutStep(),
              OnboardingStep.photos => const PhotosStep(),
              OnboardingStep.interests => const InterestsStep(),
              OnboardingStep.modes => const ModesStep(),
              OnboardingStep.location => const LocationStep(),
            },
          ),
        ),
      );
    } else if (onboarding.hasError && !onboarding.isLoading) {
      body = _LoadFailure(
        message: switch (onboarding.error) {
          final ApiException error => error.message,
          _ => unexpectedFailureMessage,
        },
        onRetry: controller.reload,
      );
    } else {
      body = const Center(
        child: CircularProgressIndicator(
          color: AppColors.purple,
          semanticsLabel: 'Loading your profile',
        ),
      );
    }

    return GradientScaffold(background: AppColors.lightBackground, child: body);
  }
}

class _LoadFailure extends ConsumerWidget {
  const _LoadFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FlowPageLayout(
      backButton: const SizedBox.shrink(),
      backButtonSpacing: 0,
      badgeText: 'Profile setup',
      badgeAsset: AppAssets.sparkle,
      title: "We couldn't load your profile",
      subtitle: message,
      content: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrimaryActionButton(label: 'Try again', onPressed: onRetry),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: () => unawaited(confirmLogOut(context, ref)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
                child: const Text('Log out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
