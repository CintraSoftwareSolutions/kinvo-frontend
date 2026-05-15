import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.title,
    this.subtitle,
    this.icon,
    this.iconWidget,
    this.iconColor,
    this.iconBg,
    this.trailing,
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
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final hasIcon = icon != null || iconWidget != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: danger ? const Color(0xFFFFE4E8) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: danger ? const Color(0xFFFFD6DD) : AppColors.divider,
          ),
        ),
        child: Row(
          children: [
            if (hasIcon) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg ?? AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: iconWidget ??
                      SvgPicture.asset(
                        icon!,
                        width: 18,
                        height: 18,
                        colorFilter: ColorFilter.mode(
                          iconColor ??
                              (danger
                                  ? const Color(0xFFEF4458)
                                  : AppColors.textPrimary),
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
                          ? const Color(0xFFEF4458)
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing!,
            ] else if (onTap != null) ...[
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: danger
                    ? const Color(0xFFEF4458)
                    : AppColors.textMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class OnOffToggle extends StatelessWidget {
  const OnOffToggle({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: value ? const Color(0xFFD1FAE5) : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          value ? 'On' : 'Off',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: value ? const Color(0xFF10B981) : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
