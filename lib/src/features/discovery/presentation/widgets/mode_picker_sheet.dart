import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../modes/presentation/mode_presentation.dart';
import '../../domain/discovery_mode.dart';

/// Lets the user pick which of their [modes] Discover shows. Resolves to the
/// mode picked, or `null` if the sheet is dismissed.
Future<DiscoveryMode?> showModePickerSheet(
  BuildContext context, {
  required List<DiscoveryMode> modes,
  required String activeMode,
}) {
  return showModalBottomSheet<DiscoveryMode>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ModePickerSheet(modes: modes, activeMode: activeMode),
  );
}

class ModePickerSheet extends StatelessWidget {
  const ModePickerSheet({
    required this.modes,
    required this.activeMode,
    super.key,
  });

  final List<DiscoveryMode> modes;

  /// The API name of the mode showing now.
  final String activeMode;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Mode',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Each mode has its own deck, filters and matches.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final mode in modes)
                      _ModeRow(
                        mode: mode,
                        active: mode.value == activeMode,
                        onTap: () => Navigator.of(context).pop(mode),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.mode,
    required this.active,
    required this.onTap,
  });

  final DiscoveryMode mode;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = modeColors(mode.value);
    return Semantics(
      button: true,
      selected: active,
      label: mode.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.purple : AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.18)
                      : colors.soft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    modeIconAsset(mode.value),
                    width: 16,
                    height: 16,
                    colorFilter: ColorFilter.mode(
                      active ? Colors.white : colors.primary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  mode.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
              if (mode.isPrimary && !active)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Text(
                    'MAIN',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              if (active)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
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
