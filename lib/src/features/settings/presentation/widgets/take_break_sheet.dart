import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// How long a break from Discover lasts.
enum BreakLength {
  day('For a day', Duration(days: 1)),
  threeDays('For 3 days', Duration(days: 3)),
  week('For a week', Duration(days: 7)),
  untilBack('Until I come back', null);

  const BreakLength(this.label, this.duration);

  final String label;

  /// `null` when the break lasts until the user ends it.
  final Duration? duration;
}

/// Asks how long a break should last. Returns `null` when dismissed.
Future<BreakLength?> showTakeBreakSheet(BuildContext context) {
  return showModalBottomSheet<BreakLength>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheet) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Take a break',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Nobody new sees you in Discover while you're away. You can "
              'come back at any time.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            for (final length in BreakLength.values)
              ListTile(
                onTap: () => Navigator.of(sheet).pop(length),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  length == BreakLength.untilBack
                      ? Icons.all_inclusive_rounded
                      : Icons.schedule_rounded,
                  color: AppColors.purple,
                ),
                title: Text(length.label),
              ),
          ],
        ),
      ),
    ),
  );
}
