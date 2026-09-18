import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../entitlements/paywall.dart';
import '../navigation/app_routes.dart';
import '../theme/app_colors.dart';

/// Explains a [paywall] and offers the upgrade that lifts it.
Future<void> showPaywallSheet(BuildContext context, Paywall paywall) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => PaywallSheet(paywall: paywall),
  );
}

class PaywallSheet extends StatelessWidget {
  const PaywallSheet({required this.paywall, super.key});

  final Paywall paywall;

  @override
  Widget build(BuildContext context) {
    final paywall = this.paywall;
    final (title, icon) = switch (paywall) {
      DailyLimitReached() => (
        "That's today's allowance",
        Icons.hourglass_bottom_rounded,
      ),
      PremiumFeature() => ('Part of Premium', Icons.workspace_premium_rounded),
    };
    final resetsAt = switch (paywall) {
      DailyLimitReached(:final resetsAt?) => _resetTime(context, resetsAt),
      _ => null,
    };

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 22),
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.purpleSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.purple, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              paywall.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            if (resetsAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'It comes back at $resetsAt.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 22),
            if (paywall.canUpgrade) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push(AppRoutes.premium);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('See Premium'),
                ),
              ),
              const SizedBox(height: 6),
            ],
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              child: Text(paywall.canUpgrade ? 'Not now' : 'OK'),
            ),
          ],
        ),
      ),
    );
  }

  /// [resetsAt] as a time of day on the phone's clock, such as "1:00 AM".
  static String _resetTime(BuildContext context, DateTime resetsAt) {
    final local = resetsAt.toLocal();
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
  }
}
