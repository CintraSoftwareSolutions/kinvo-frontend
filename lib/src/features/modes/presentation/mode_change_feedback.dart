import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/widgets/paywall_sheet.dart';
import 'controllers/user_modes_controller.dart';

/// Tells the user how a change to their modes went, wherever it was made:
/// the upgrade offer at the plan's limit, the way to get verified for a mode
/// that needs it, or what went wrong. [done] is said when it worked.
Future<void> showModeChangeOutcome(
  BuildContext context,
  ModeChange outcome, {
  required String modeLabel,
  required String done,
}) async {
  switch (outcome) {
    case ModeChanged():
      _tell(context, done);
    case ModeNeedsUpgrade(:final paywall):
      await showPaywallSheet(context, paywall);
    case ModeNeedsVerification():
      await offerVerification(context, modeLabel: modeLabel);
    case LastModeKept():
      _tell(
        context,
        'Keep at least one mode on. Discover needs one to show you people.',
      );
    case ModeChangeFailed(:final message):
      _tell(context, message);
  }
}

/// Asks before switching a mode on: it puts the user in front of everyone
/// using [modeLabel], so it shouldn't happen from a stray tap.
Future<bool> confirmTurnOn(
  BuildContext context, {
  required String modeLabel,
}) async {
  final turnOn = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Turn on $modeLabel?'),
      content: Text(
        "People using $modeLabel will see your profile there, and you'll see "
        'them in Discover. You can switch it off any time in Your modes.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Not now'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Turn on'),
        ),
      ],
    ),
  );
  return turnOn ?? false;
}

/// Explains that [modeLabel] is only for people who have verified their
/// identity, and offers to start.
Future<void> offerVerification(
  BuildContext context, {
  required String modeLabel,
}) async {
  final start = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Verify to use $modeLabel'),
      content: Text(
        '$modeLabel is only for people who have verified their identity. '
        'Once your verification is approved, you can switch it on.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Not now'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Get verified'),
        ),
      ],
    ),
  );
  if (start == true && context.mounted) {
    await context.push<void>(AppRoutes.verificationMethods);
  }
}

void _tell(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
