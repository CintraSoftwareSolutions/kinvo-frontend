import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../controllers/location_step_controller.dart';
import '../controllers/onboarding_controller.dart';
import '../widgets/onboarding_step_layout.dart';

class LocationStep extends ConsumerWidget {
  const LocationStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(
      onboardingControllerProvider.select((state) => state.value?.profile),
    );
    final isFinishing = ref.watch(
      onboardingControllerProvider.select(
        (state) => state.value?.isFinishing ?? false,
      ),
    );
    final progress = ref.watch(locationStepControllerProvider);
    final controller = ref.read(locationStepControllerProvider.notifier);
    final hasLocation = profile?.hasLocation ?? false;
    final busy = progress.isLocating || isFinishing;

    return OnboardingStepLayout(
      step: OnboardingStep.location,
      title: 'Find people near you',
      subtitle:
          'Kinvo uses your approximate location to show you people nearby. '
          'Others only see how far away you are, never where you are.',
      error: progress.error,
      actionLabel: hasLocation ? 'Finish setup' : 'Share my location',
      actionLoading: hasLocation ? isFinishing : progress.isLocating,
      onAction: busy
          ? null
          : hasLocation
          ? () => unawaited(
              ref.read(onboardingControllerProvider.notifier).finish(),
            )
          : () => unawaited(controller.shareLocation()),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LocationSummary(
            hasLocation: hasLocation,
            placeName: profile?.placeName,
          ),
          if (hasLocation)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: busy
                    ? null
                    : () => unawaited(controller.shareLocation()),
                child: Text(
                  progress.isLocating
                      ? 'Updating your location…'
                      : 'Update my location',
                ),
              ),
            ),
          if (progress.problem case final problem?) ...[
            const SizedBox(height: 12),
            _ProblemNotice(
              problem: problem,
              onOpenSettings: problem.needsSettings
                  ? () => unawaited(controller.openSettings())
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _LocationSummary extends StatelessWidget {
  const _LocationSummary({required this.hasLocation, required this.placeName});

  final bool hasLocation;
  final String? placeName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = hasLocation ? 'Location added' : 'Not shared yet';
    final detail = hasLocation
        ? (placeName ?? "We'll show you people near where you are.")
        : "We'll ask your phone for permission.";

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasLocation ? AppColors.greenSoft : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              hasLocation
                  ? Icons.check_circle_rounded
                  : Icons.location_on_outlined,
              color: hasLocation ? AppColors.green : AppColors.purple,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleLarge?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProblemNotice extends StatelessWidget {
  const _ProblemNotice({required this.problem, required this.onOpenSettings});

  final LocationProblem problem;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final onOpenSettings = this.onOpenSettings;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              problem.message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.danger,
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (onOpenSettings != null)
              TextButton(
                onPressed: onOpenSettings,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  padding: EdgeInsets.zero,
                ),
                child: const Text('Open Settings'),
              )
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
