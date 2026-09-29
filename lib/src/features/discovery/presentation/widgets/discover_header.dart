import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/kinvo_colors.dart';

/// The top of Discover: which mode is showing, filters and notifications.
class DiscoverHeader extends StatelessWidget {
  const DiscoverHeader({
    required this.modeLabel,
    required this.modeColor,
    this.notificationCount = 0,
    this.onModeTap,
    this.onFiltersTap,
    this.onNotificationsTap,
    super.key,
  });

  final String modeLabel;
  final Color modeColor;
  final int notificationCount;

  /// Opens the mode picker. Without it the mode can't be changed from here.
  final VoidCallback? onModeTap;
  final VoidCallback? onFiltersTap;
  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Flexible(
            child: _ModePill(
              label: modeLabel,
              color: modeColor,
              onTap: onModeTap,
            ),
          ),
          const SizedBox(width: 10),
          const Spacer(),
          _CircleIconButton(
            icon: AppAssets.filters,
            tooltip: 'Filters',
            onTap: onFiltersTap,
          ),
          const SizedBox(width: 10),
          _CircleIconButton(
            icon: AppAssets.bell,
            tooltip: 'Notifications',
            badgeCount: notificationCount,
            onTap: onNotificationsTap,
          ),
        ],
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({required this.label, required this.color, this.onTap});

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: onTap == null ? label : 'Mode: $label. Change mode',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: context.colors.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: context.colors.textMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    this.badgeCount = 0,
    this.onTap,
  });

  final String icon;
  final String tooltip;
  final int badgeCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: badgeCount > 0 ? '$tooltip, $badgeCount new' : tooltip,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.colors.divider),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    icon,
                    width: 18,
                    height: 18,
                    colorFilter: ColorFilter.mode(
                      onTap == null
                          ? context.colors.textMuted
                          : context.colors.textPrimary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.danger,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: context.colors.surface,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$badgeCount',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.colors.onAccent,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
