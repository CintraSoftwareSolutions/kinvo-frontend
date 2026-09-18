import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/flow_widgets.dart';

/// Invites the user to turn notifications on, before the system asks.
/// Returns whether they'd like to.
///
/// The system prompt can only be shown so many times, and an unexplained one
/// is easy to refuse, so the app says why first.
Future<bool> showPushInvitationSheet(BuildContext context) async {
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheet) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: 22),
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.purpleSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: AppColors.purple,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Don't miss a match",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Turn on notifications to hear when someone likes you back, '
              'sends you a message, or confirms a plan. You can choose which '
              'ones in Settings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            PrimaryActionButton(
              label: 'Turn on notifications',
              borderRadius: 999,
              onPressed: () => Navigator.of(sheet).pop(true),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(sheet).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    ),
  );
  return accepted ?? false;
}
