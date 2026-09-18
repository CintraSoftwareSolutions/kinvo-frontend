import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/flow_widgets.dart';
import '../../../auth/presentation/log_out.dart';
import '../controllers/onboarding_controller.dart';

/// The frame every onboarding step shares: where the user is, the step's
/// content, what went wrong, and the way forward.
class OnboardingStepLayout extends ConsumerWidget {
  const OnboardingStepLayout({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    this.actionLoading = false,
    this.error,
    super.key,
  });

  final OnboardingStep step;
  final String title;
  final String subtitle;
  final Widget body;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool actionLoading;

  /// Why the step's last action failed.
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finishError = ref.watch(
      onboardingControllerProvider.select((state) => state.value?.error),
    );

    return FlowPageLayout(
      backButton: step.isFirst
          ? const SizedBox.shrink()
          : AppBackButton(
              onTap: ref.read(onboardingControllerProvider.notifier).back,
            ),
      backButtonSpacing: step.isFirst ? 0 : 18,
      badgeText: 'Step ${step.index + 1} of ${OnboardingStep.values.length}',
      badgeAsset: AppAssets.sparkle,
      title: title,
      subtitle: subtitle,
      content: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            body,
            for (final message in [?error, ?finishError]) ...[
              const SizedBox(height: 14),
              FormErrorBanner(message: message),
            ],
            const SizedBox(height: 16),
            PrimaryActionButton(
              label: actionLabel,
              loading: actionLoading,
              onPressed: onAction,
            ),
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
