import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/kinvo_colors.dart';
import '../../../../core/theme/motion.dart';

/// The buttons under the card: pass, like and super like, in the words of
/// the mode, and rewind.
class DeckControls extends StatelessWidget {
  const DeckControls({
    required this.likeLabel,
    required this.superLikeLabel,
    required this.modeIcon,
    required this.modeColor,
    required this.enabled,
    required this.onRewind,
    required this.onPass,
    required this.onLike,
    required this.onSuperLike,
    super.key,
  });

  final String likeLabel;
  final String superLikeLabel;
  final String modeIcon;
  final Color modeColor;

  /// False while a swipe is on its way, so swipes go one at a time.
  final bool enabled;

  final VoidCallback onRewind;
  final VoidCallback onPass;
  final VoidCallback onLike;
  final VoidCallback onSuperLike;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.divider),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow,
            blurRadius: 18,
            offset: const Offset(0, 6),
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
                    Text(
                      'DECK CONTROLS',
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Passing never uses up your likes for today.',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _RewindChip(onTap: enabled ? onRewind : null),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ActionButton(
                  icon: AppAssets.closeX,
                  iconColor: context.colors.danger,
                  backgroundColor: context.colors.surface,
                  border: context.colors.border,
                  label: 'Pass',
                  glowColor: context.colors.danger,
                  onTap: enabled ? onPass : null,
                ),
              ),
              Expanded(
                child: _ActionButton(
                  icon: modeIcon,
                  iconColor: context.colors.onAccent,
                  backgroundColor: modeColor,
                  border: modeColor,
                  label: likeLabel,
                  glowColor: modeColor,
                  onTap: enabled ? onLike : null,
                  primary: true,
                ),
              ),
              Expanded(
                child: _ActionButton(
                  icon: AppAssets.starOutline,
                  iconColor: context.colors.tint(Hue.amber).color,
                  backgroundColor: context.colors.tint(Hue.amber).soft,
                  border: context.colors
                      .tint(Hue.amber)
                      .color
                      .withValues(alpha: 0.5),
                  label: superLikeLabel,
                  glowColor: context.colors.tint(Hue.amber).color,
                  onTap: enabled ? onSuperLike : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewindChip extends StatelessWidget {
  const _RewindChip({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: 'Rewind last swipe',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: context.colors.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.undo_rounded,
                size: 14,
                color: context.colors.textPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                'Rewind',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
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
    required this.glowColor,
    this.onTap,
    this.primary = false,
  });

  final String icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color border;
  final String label;
  final Color glowColor;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final size = primary ? 70.0 : 58.0;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          opacity: onTap == null ? 0.55 : 1,
          duration: context.motion(const Duration(milliseconds: 150)),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
