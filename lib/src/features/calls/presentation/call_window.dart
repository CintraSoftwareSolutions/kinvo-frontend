import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What a call asks of the window it is drawn in.
///
/// Two things, both only for as long as a call is on screen:
///
/// - **Over the lock screen.** Answering from the lock screen starts the app,
///   and an app that opens behind the keyguard has answered a call the person
///   cannot see. Asked for here rather than declared in the manifest, because
///   a manifest cannot say "only the call": every other screen in Kinvo must
///   stay behind the lock screen, chats most of all.
/// - **Awake.** A video call is watched, and a phone that dims in the middle
///   of one has stopped being a video call.
abstract interface class CallWindow {
  /// Applies both, replacing whatever was asked for before.
  Future<void> set({required bool showOverLockScreen, required bool keepAwake});

  /// Back to an ordinary screen.
  Future<void> clear();
}

/// [CallWindow] over the platform channel in `CallWindowBridge.kt`.
final class PlatformCallWindow implements CallWindow {
  const PlatformCallWindow();

  static const _channel = MethodChannel('kinvo/call_window');

  @override
  Future<void> set({
    required bool showOverLockScreen,
    required bool keepAwake,
  }) async {
    try {
      await _channel.invokeMethod<void>('set', {
        'showOverLockScreen': showOverLockScreen,
        'keepAwake': keepAwake,
      });
    } on PlatformException catch (error, stackTrace) {
      // The call itself does not depend on this. A phone that refuses is a
      // phone where the call is shown the ordinary way.
      developer.log(
        'Could not set the call window.',
        name: 'kinvo.calls',
        error: error,
        stackTrace: stackTrace,
      );
    } on MissingPluginException {
      // A platform with no bridge, such as an iPhone.
    }
  }

  @override
  Future<void> clear() => set(showOverLockScreen: false, keepAwake: false);
}

/// What platforms without the bridge get. On an iPhone CallKit draws the call
/// over the lock screen itself, and idle timing belongs to the system.
final class NoCallWindow implements CallWindow {
  const NoCallWindow();

  @override
  Future<void> set({
    required bool showOverLockScreen,
    required bool keepAwake,
  }) async {}

  @override
  Future<void> clear() async {}
}

final callWindowProvider = Provider<CallWindow>((ref) {
  return defaultTargetPlatform == TargetPlatform.android
      ? const PlatformCallWindow()
      : const NoCallWindow();
});
