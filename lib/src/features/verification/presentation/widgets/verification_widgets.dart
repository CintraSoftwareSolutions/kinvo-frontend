import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';

/// How far through the three steps the attempt is, under the page header.
class VerificationSteps extends StatelessWidget {
  const VerificationSteps({required this.stepIndex, super.key});

  /// 0 for choosing a method, 1 for the document, 2 for sent.
  final int stepIndex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Row(
        children: [
          for (var step = 0; step < 3; step++) ...[
            Expanded(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: step <= stepIndex
                      ? AppColors.purple
                      : AppColors.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            if (step < 2) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

/// A round icon above a title, for the state the screen is reporting.
class VerificationBadge extends StatelessWidget {
  const VerificationBadge({
    required this.asset,
    required this.background,
    required this.foreground,
    this.size = 80,
    super.key,
  });

  final String asset;
  final Color background;
  final Color foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Center(
        child: SvgPicture.asset(
          asset,
          width: size / 2,
          height: size / 2,
          colorFilter: ColorFilter.mode(foreground, BlendMode.srcIn),
        ),
      ),
    );
  }
}

/// One way of verifying, as a card that starts it.
class VerificationMethodCard extends StatelessWidget {
  const VerificationMethodCard({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.onTap,
    super.key,
  });

  final String icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String meta;

  /// Null while something else is happening, so two attempts can't be started
  /// by an impatient double tap.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    icon,
                    width: 18,
                    height: 18,
                    colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A short list of advice, such as what makes a photo usable.
class VerificationTips extends StatelessWidget {
  const VerificationTips({
    required this.title,
    required this.tips,
    this.background = const Color(0xFFFFE4E8),
    this.titleColor = const Color(0xFFB91C1C),
    super.key,
  });

  final String title;
  final List<String> tips;
  final Color background;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 6),
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
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
