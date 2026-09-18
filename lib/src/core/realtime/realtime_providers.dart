import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/account_providers.dart';
import '../auth/auth_providers.dart';
import '../auth/session_status.dart';
import '../demo/demo_mode.dart';
import '../network/network_providers.dart';
import 'realtime_connection.dart';
import 'realtime_socket.dart';

/// Creates the socket behind the live connection. Tests replace it with a
/// fake server.
final realtimeSocketFactoryProvider = Provider<RealtimeSocketFactory>((ref) {
  final server = ref.watch(appConfigProvider).apiBaseUrl;
  return (listener) =>
      SocketIoRealtimeSocket(server: server, listener: listener);
});

/// The live connection. [realtimeKeeperProvider] decides when it's open.
final realtimeConnectionProvider = Provider<RealtimeConnection>((ref) {
  final connection = RealtimeConnection(
    session: ref.watch(sessionManagerProvider),
    createSocket: ref.watch(realtimeSocketFactoryProvider),
  );
  ref.onDispose(connection.dispose);
  return connection;
});

/// Whether the live connection is open, for anything that shows live data and
/// must catch up after a gap.
final realtimeStatusProvider =
    NotifierProvider<RealtimeStatusNotifier, RealtimeStatus>(
      RealtimeStatusNotifier.new,
    );

class RealtimeStatusNotifier extends Notifier<RealtimeStatus> {
  @override
  RealtimeStatus build() {
    final status = ref.watch(realtimeConnectionProvider).status;
    void update() => state = status.value;
    status.addListener(update);
    ref.onDispose(() => status.removeListener(update));
    return status.value;
  }
}

/// Whether the app is on screen. `inactive`, such as with the notification
/// shade pulled down, still counts.
final appInForegroundProvider = NotifierProvider<AppForegroundNotifier, bool>(
  AppForegroundNotifier.new,
);

class AppForegroundNotifier extends Notifier<bool> {
  @override
  bool build() {
    final listener = AppLifecycleListener(
      onStateChange: (next) => state = _isForeground(next),
    );
    ref.onDispose(listener.dispose);
    return _isForeground(WidgetsBinding.instance.lifecycleState);
  }

  static bool _isForeground(AppLifecycleState? state) {
    return switch (state) {
      null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
      AppLifecycleState.hidden ||
      AppLifecycleState.paused ||
      AppLifecycleState.detached => false,
    };
  }
}

/// How long the connection stays open after the app leaves the screen, so a
/// trip to the camera or photo picker doesn't drop it.
const realtimeBackgroundGrace = Duration(seconds: 30);

/// Keeps the live connection open while it's any use: signed in to an account
/// that's set up, outside the demo, with the app on screen. Listen to this
/// once, for as long as the app runs.
///
/// Signing out closes the connection at once; leaving the screen closes it
/// after [realtimeBackgroundGrace].
final realtimeKeeperProvider = Provider<void>((ref) {
  final connection = ref.watch(realtimeConnectionProvider);

  void update() {
    final signedIn = ref.read(sessionStatusProvider) is SignedIn;
    final account = ref.read(currentAccountProvider).value;
    final eligible =
        signedIn &&
        (account?.isOnboarded ?? false) &&
        !ref.read(demoSessionProvider);

    if (!eligible) {
      connection.setWanted(false);
    } else if (!ref.read(appInForegroundProvider)) {
      connection.setWanted(false, grace: realtimeBackgroundGrace);
    } else {
      connection.setWanted(true);
    }
  }

  // Opening or closing the connection changes its status, which providers
  // listen to, and these changes can be noticed while providers or widgets
  // are being built, when no provider may change. So the update runs just
  // after, once for any number of changes together.
  var updateScheduled = false;
  void scheduleUpdate() {
    if (updateScheduled) return;
    updateScheduled = true;
    scheduleMicrotask(() {
      updateScheduled = false;
      if (ref.mounted) update();
    });
  }

  ref
    ..listen(sessionStatusProvider, (_, _) => scheduleUpdate())
    ..listen(currentAccountProvider, (_, _) => scheduleUpdate())
    ..listen(demoSessionProvider, (_, _) => scheduleUpdate())
    ..listen(appInForegroundProvider, (_, _) => scheduleUpdate());
  scheduleUpdate();
});
