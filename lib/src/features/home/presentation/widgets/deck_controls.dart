import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/discover_mode.dart';

class DeckControls extends StatelessWidget {
  const DeckControls({
    required this.mode,
    this.onRewind,
    this.onPass,
    this.onPrimary,
    this.onSuperLike,
    super.key,
  });

  final DiscoverMode mode;
  final VoidCallback? onRewind;
  final VoidCallback? onPass;
  final VoidCallback? onPrimary;
  final VoidCallback? onSuperLike;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _UpHint(color: mode.primary),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0C132A),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DECK CONTROLS',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${mode.label} keeps the same dock, but the primary action changes with intent.',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _RewindChip(onTap: onRewind),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ActionButton(
                    icon: AppAssets.closeX,
                    iconColor: const Color(0xFFEF4444),
                    backgroundColor: Colors.white,
                    border: const Color(0xFFE5E7EB),
                    label: 'Pass',
                    subtitle: 'Skip',
                    onTap: onPass,
                    glowColor: const Color(0xFFEF4444),
                  ),
                  _ActionButton(
                    icon: mode.actionIcon,
                    iconColor: Colors.white,
                    backgroundColor: mode.primary,
                    border: mode.primary,
                    label: mode.actionLabel,
                    subtitle: mode.actionSubtitle,
                    onTap: onPrimary,
                    glowColor: mode.primary,
                    primary: true,
                  ),
                  _ActionButton(
                    icon: AppAssets.starOutline,
                    iconColor: const Color(0xFFF59E0B),
                    backgroundColor: const Color(0xFFFFF7E5),
                    border: const Color(0xFFFCD34D),
                    label: 'Super Like',
                    subtitle: 'Stand out',
                    onTap: onSuperLike,
                    glowColor: const Color(0xFFF59E0B),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UpHint extends StatelessWidget {
  const _UpHint({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.arrow_upward_rounded, size: 16, color: color),
    );
  }
}

class _RewindChip extends StatelessWidget {
  const _RewindChip({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh_rounded, size: 14, color: AppColors.textPrimary),
            SizedBox(width: 6),
            Text(
              'Rewind',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.border,
    required this.label,
    required this.subtitle,
    required this.glowColor,
    this.onTap,
    this.primary = false,
  });

  final String icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color border;
  final String label;
  final String subtitle;
  final Color glowColor;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final double size = primary ? 70 : 58;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(color: border, width: primary ? 0 : 1.5),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: primary ? 0.35 : 0.12),
                  blurRadius: primary ? 22 : 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: SvgPicture.asset(
                icon,
                width: primary ? 28 : 22,
                height: primary ? 28 : 22,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
