import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/config/server_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../modes/presentation/mode_presentation.dart';
import '../controllers/modes_step_controller.dart';
import '../controllers/onboarding_controller.dart';
import '../widgets/onboarding_step_layout.dart';

class ModesStep extends ConsumerWidget {
  const ModesStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingControllerProvider).value;
    final form = ref.watch(modesStepControllerProvider);
    final controller = ref.read(modesStepControllerProvider.notifier);
    if (onboarding == null) return const SizedBox.shrink();

    final maxEnabled = form.maxEnabled;
    return OnboardingStepLayout(
      step: OnboardingStep.modes,
      title: "What you're here for",
      subtitle: maxEnabled == null
          ? 'Choose the modes you want to use. Your first choice is your '
                'main mode.'
          : 'Choose up to $maxEnabled modes. Your first choice is your main '
                'mode.',
      error: form.error,
      actionLabel: 'Continue',
      actionLoading: form.isSubmitting,
      onAction: () => unawaited(controller.submit()),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, option) in onboarding.config.modes.indexed) ...[
            if (index > 0) const SizedBox(height: 8),
            _ModeTile(
              option: option,
              isMain:
                  form.selected.isNotEmpty &&
                  form.selected.first == option.value,
              isSelected: form.selected.contains(option.value),
              canEnable: onboarding.modes.canEnable(option.value),
              needsVerification: onboarding.modes.needsVerification(
                option.value,
              ),
              onTap: form.isSubmitting
                  ? null
                  : () => controller.toggle(option.value),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.option,
    required this.isMain,
    required this.isSelected,
    required this.canEnable,
    required this.needsVerification,
    required this.onTap,
  });

  final ModeOption option;
  final bool isMain;
  final bool isSelected;
  final bool canEnable;
  final bool needsVerification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final available = canEnable || isSelected;
    final description = canEnable
        ? option.description
        : needsVerification
        ? 'Verify your identity to unlock this mode.'
        : "This mode isn't available to you yet.";
    final textTheme = Theme.of(context).textTheme;

    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: isSelected,
        enabled: available && onTap != null,
        hint: isMain ? 'Main mode' : null,
        child: GestureDetector(
          onTap: available ? onTap : null,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.purpleSoft : AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.purpleLight : Colors.transparent,
              ),
            ),
            child: Opacity(
              opacity: available ? 1 : 0.55,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        modeIconAsset(option.value),
                        width: 20,
                        height: 20,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                option.label,
                                style: textTheme.titleLarge?.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (isMain) ...[
                              const SizedBox(width: 8),
                              const ExcludeSemantics(child: _MainBadge()),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                            height: 1.35,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : canEnable
                        ? Icons.radio_button_unchecked_rounded
                        : Icons.lock_outline_rounded,
                    color: isSelected ? AppColors.purple : AppColors.textMuted,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MainBadge extends StatelessWidget {
  const _MainBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.purple,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Main',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
