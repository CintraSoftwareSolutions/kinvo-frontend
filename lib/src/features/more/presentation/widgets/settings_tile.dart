import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/kinvo_colors.dart';
import '../../../../core/widgets/count_badge.dart';

/// A row that opens somewhere: an icon, a title, a line about it, and an
/// arrow — with a count beside the arrow when something there is waiting.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.title,
    this.subtitle,
    this.icon,
    this.iconWidget,
    this.iconColor,
    this.iconBg,
    this.badgeCount = 0,
    this.onTap,
    this.danger = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? icon;
  final Widget? iconWidget;
  final Color? iconColor;
  final Color? iconBg;

  /// How many things behind the row want attention, such as unread
  /// notifications.
  final int badgeCount;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final hasIcon = icon != null || iconWidget != null;
    // One node for screen readers: what the row is, and what's waiting there.
    return Semantics(
      button: onTap != null,
      label: [
        title,
        ?subtitle,
        if (badgeCount > 0) '$badgeCount new',
      ].join(', '),
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: danger ? context.colors.dangerSoft : context.colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: danger
                  ? context.colors.danger.withValues(alpha: 0.3)
                  : context.colors.divider,
            ),
          ),
          child: Row(
            children: [
              if (hasIcon) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg ?? context.colors.surfaceSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child:
                        iconWidget ??
                        SvgPicture.asset(
                          icon!,
                          width: 18,
                          height: 18,
                          colorFilter: ColorFilter.mode(
                            iconColor ??
                                (danger
                                    ? context.colors.danger
                                    : context.colors.textPrimary),
                            BlendMode.srcIn,
                          ),
                        ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: danger
                            ? context.colors.danger
                            : context.colors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 10),
                CountBadge(badgeCount, size: CountBadgeSize.large),
              ],
              if (onTap != null) ...[
                SizedBox(width: badgeCount > 0 ? 4 : 10),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: danger
                      ? context.colors.danger
                      : context.colors.textMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
