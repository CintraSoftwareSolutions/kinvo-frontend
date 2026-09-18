import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_providers.dart';
import 'core/auth/session_status.dart';
import 'core/navigation/app_router.dart';
import 'core/push/push_providers.dart';
import 'core/realtime/realtime_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_messenger.dart';
import 'features/notifications/presentation/push_messages.dart';

class KinvoApp extends ConsumerStatefulWidget {
  const KinvoApp({super.key});

  @override
  ConsumerState<KinvoApp> createState() => _KinvoAppState();
}

class _KinvoAppState extends ConsumerState<KinvoApp> {
  @override
  Widget build(BuildContext context) {
    final messengerKey = ref.watch(appMessengerKeyProvider);

    // The router sends the user back to the welcome screen; this tells them
    // why, rather than leaving them to wonder what they did.
    ref.listen(sessionStatusProvider, (previous, next) {
      if (previous is SignedIn &&
          next == const SignedOut(SignOutReason.sessionEnded)) {
        messengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Your session has ended. Please log in again.'),
          ),
        );
      }
    });

    // For as long as the app runs: the live connection opens and closes as
    // the session and the app's visibility change, this device stays
    // registered for push notifications, and tapped or arriving notifications
    // are handled.
    ref
      ..listen(realtimeKeeperProvider, (_, _) {})
      ..listen(pushRegistrationKeeperProvider, (_, _) {})
      ..listen(pushMessagesKeeperProvider, (_, _) {});

    return MaterialApp.router(
      title: 'Kinvo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      scaffoldMessengerKey: messengerKey,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
