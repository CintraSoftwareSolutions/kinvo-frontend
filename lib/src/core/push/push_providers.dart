import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../auth/session_status.dart';
import '../device/device_providers.dart';
import '../network/api_client_provider.dart';
import '../realtime/realtime_providers.dart';
import 'app_icon_badge.dart';
import 'firebase_push_messaging.dart';
import 'push_config.dart';
import 'push_messaging.dart';
import 'push_token_registrar.dart';

/// The Firebase project this build receives push notifications from, or
/// `null` when it has none.
final pushConfigProvider = Provider<PushConfig?>(
  (ref) => PushConfig.fromEnvironment(),
);

/// Push notifications on this device: Firebase where the build has its
/// settings for this platform, and nothing anywhere else. Tests replace it.
final pushMessagingProvider = Provider<PushMessaging>((ref) {
  final options = ref
      .watch(pushConfigProvider)
      ?.optionsFor(defaultTargetPlatform);
  if (options == null) return const UnavailablePushMessaging();
  return FirebasePushMessaging(options);
});

/// The number on the app's icon.
final appIconBadgeProvider = Provider<AppIconBadge>((ref) {
  return defaultTargetPlatform == TargetPlatform.iOS
      ? const IosAppIconBadge()
      : const NoAppIconBadge();
});

final pushTokenRegistrarProvider = Provider<PushTokenRegistrar>((ref) {
  return PushTokenRegistrar(
    messaging: ref.watch(pushMessagingProvider),
    api: ref.watch(apiClientProvider),
    clientInfo: () => ref.read(clientInfoProvider.future),
  );
});

/// Keeps this device registered for the signed-in account's notifications,
/// for as long as the app runs: when a session starts, when the token
/// changes, and when the app comes back to the screen, since notifications
/// may have been switched on or off in the phone's settings meanwhile. When
/// the session ends the token is thrown away. Listen to this once.
final pushRegistrationKeeperProvider = Provider<void>((ref) {
  final messaging = ref.watch(pushMessagingProvider);
  if (!messaging.isAvailable) return;
  final registrar = ref.watch(pushTokenRegistrarProvider);

  StreamSubscription<String>? tokenRefreshes;

  void sync() {
    if (ref.read(sessionStatusProvider) is SignedIn) {
      unawaited(registrar.sync());
    }
  }

  void sessionChanged(SessionStatus? previous, SessionStatus next) {
    if (next is SignedIn) {
      tokenRefreshes ??= messaging.tokenRefreshes.listen((_) => sync());
      sync();
    } else if (previous is SignedIn) {
      unawaited(tokenRefreshes?.cancel());
      tokenRefreshes = null;
      unawaited(registrar.signedOut());
    }
  }

  ref
    ..onDispose(() => unawaited(tokenRefreshes?.cancel()))
    ..listen(sessionStatusProvider, sessionChanged, fireImmediately: true)
    ..listen(appInForegroundProvider, (_, foreground) {
      if (foreground) sync();
    });
});
