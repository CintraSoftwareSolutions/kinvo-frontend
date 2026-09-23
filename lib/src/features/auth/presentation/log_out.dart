import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/demo/demo_mode.dart';
import '../../../core/theme/app_colors.dart';
import '../data/social_auth_service.dart';

/// Asks whether to log out and, if the user agrees, logs out.
Future<void> confirmLogOut(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Log out of Kinvo?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialog).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.purple),
          child: const Text('Log out'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await logOut(ref);
}

/// Ends the session on this device, or leaves the demo. The router then
/// returns to the welcome screen.
Future<void> logOut(WidgetRef ref) async {
  // Read before anything changes: leaving the demo closes the current screen.
  final session = ref.read(sessionManagerProvider);
  final social = ref.read(socialAuthServiceProvider);
  ref.read(demoSessionProvider.notifier).end();
  await session.signOut();

  // Google is told too, so the next sign-in asks which account to use
  // rather than reaching for the one that just left. It cannot fail in a
  // way that matters: the Kinvo session has already ended.
  await social.forgetGoogle();
}
