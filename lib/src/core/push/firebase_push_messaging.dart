import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_messaging.dart';

/// [PushMessaging] on Firebase Cloud Messaging.
///
/// Firebase starts on first use rather than at launch, so a build that never
/// needs push, such as one only ever used in the demo, never starts it.
final class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging(this._options, {TargetPlatform? platform})
    : _platform = platform ?? defaultTargetPlatform;

  final FirebaseOptions _options;
  final TargetPlatform _platform;
  Future<FirebaseMessaging>? _ready;

  @override
  bool get isAvailable => true;

  @override
  Future<PushPermission> permission() async {
    final settings = await (await _messaging()).getNotificationSettings();
    return _read(settings.authorizationStatus);
  }

  @override
  Future<PushPermission> requestPermission() async {
    final settings = await (await _messaging()).requestPermission();
    return _read(settings.authorizationStatus);
  }

  @override
  Future<String?> token() async {
    final messaging = await _messaging();
    try {
      // Until Apple has registered the app for remote notifications there is
      // no token, and asking for one only fails.
      if (_platform == TargetPlatform.iOS &&
          await messaging.getAPNSToken() == null) {
        return null;
      }
      return await messaging.getToken();
    } on Object catch (error, stackTrace) {
      // Typically offline, or Google Play services are unavailable. The next
      // attempt, or a token refresh, tries again.
      _log('Could not get a push token.', error, stackTrace);
      return null;
    }
  }

  @override
  Stream<String> get tokenRefreshes {
    return _started((messaging) => messaging.onTokenRefresh);
  }

  @override
  Future<void> deleteToken() async {
    try {
      await (await _messaging()).deleteToken();
    } on Object catch (error, stackTrace) {
      _log('Could not delete the push token.', error, stackTrace);
    }
  }

  @override
  Stream<PushMessage> get foregroundMessages {
    return _started((_) => FirebaseMessaging.onMessage.map(_message));
  }

  @override
  Stream<PushMessage> get openedMessages {
    return _started((_) => FirebaseMessaging.onMessageOpenedApp.map(_message));
  }

  @override
  Future<PushMessage?> initialMessage() async {
    try {
      final message = await (await _messaging()).getInitialMessage();
      return message == null ? null : _message(message);
    } on Object catch (error, stackTrace) {
      _log(
        'Could not read the notification that opened the app.',
        error,
        stackTrace,
      );
      return null;
    }
  }

  /// The stream [of] gives once Firebase has started, or an empty one when
  /// it can't start, which is logged: a listener could do nothing about it.
  Stream<T> _started<T>(
    Stream<T> Function(FirebaseMessaging messaging) of,
  ) async* {
    final FirebaseMessaging messaging;
    try {
      messaging = await _messaging();
    } on Object catch (error, stackTrace) {
      _log('Push notifications could not start.', error, stackTrace);
      return;
    }
    yield* of(messaging);
  }

  Future<FirebaseMessaging> _messaging() async {
    final ready = _ready ??= _start();
    try {
      return await ready;
    } on Object {
      // Tried again next time, rather than failing for as long as the app runs.
      if (identical(_ready, ready)) _ready = null;
      rethrow;
    }
  }

  Future<FirebaseMessaging> _start() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: _options);
    }
    final messaging = FirebaseMessaging.instance;
    // A notification arriving while the app is open shows as the app's own
    // banner, which knows not to interrupt the conversation it's about. Only
    // the app icon badge is left to the system.
    await messaging.setForegroundNotificationPresentationOptions(badge: true);
    return messaging;
  }

  PushPermission _read(AuthorizationStatus status) {
    return switch (status) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional => PushPermission.granted,
      AuthorizationStatus.notDetermined => PushPermission.requestable,
      // On Android a refusal can be asked about again, until the system stops
      // showing the prompt. On iPhone it's final.
      AuthorizationStatus.denied =>
        _platform == TargetPlatform.android
            ? PushPermission.requestable
            : PushPermission.blocked,
      AuthorizationStatus.deniedPermanently => PushPermission.blocked,
    };
  }

  static PushMessage _message(RemoteMessage message) {
    return PushMessage(
      title: message.notification?.title,
      body: message.notification?.body,
      data: {
        for (final MapEntry(:key, :value) in message.data.entries)
          if (value != null) key: '$value',
      },
    );
  }

  static void _log(String message, Object error, StackTrace stackTrace) {
    developer.log(
      message,
      name: 'kinvo.push',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
