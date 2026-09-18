import 'package:flutter/foundation.dart';

/// Whether Kinvo may show notifications on this device.
enum PushPermission {
  /// Allowed, fully or provisionally.
  granted,

  /// Not allowed yet, and asking would show the system prompt.
  requestable,

  /// Refused. Only the phone's settings can allow them now.
  blocked,
}

/// A push notification that reached the app.
@immutable
final class PushMessage {
  const PushMessage({required this.data, this.title, this.body});

  final String? title;
  final String? body;

  /// What the notification is about, for opening the right screen. Push data
  /// values always arrive as strings.
  final Map<String, String> data;
}

/// Push notifications for this device, reduced to what the app uses, so tests
/// can stand in for Firebase.
abstract interface class PushMessaging {
  /// False in builds without Firebase settings, where nothing here does
  /// anything.
  bool get isAvailable;

  /// What this device allows. Throws when it can't be asked, such as when
  /// Firebase can't start.
  Future<PushPermission> permission();

  /// Shows the system prompt when it can be shown, and returns the answer.
  /// Throws when the device can't be asked.
  Future<PushPermission> requestPermission();

  /// This installation's push token, or `null` when there isn't one to be had
  /// yet, such as on an iPhone before Apple has registered it. A token that
  /// arrives later is announced on [tokenRefreshes].
  Future<String?> token();

  /// New tokens, whenever the platform replaces the old one.
  Stream<String> get tokenRefreshes;

  /// Discards this installation's token, so nothing sent to it arrives. The
  /// next [token] is a new one.
  Future<void> deleteToken();

  /// Notifications that arrive while the app is on screen. The system shows
  /// none of these itself.
  ///
  /// This and the other streams never fail: a device that can't receive
  /// notifications just has none.
  Stream<PushMessage> get foregroundMessages;

  /// Notifications the user tapped while the app was in the background.
  Stream<PushMessage> get openedMessages;

  /// The notification the user tapped to launch the app, if they did, and
  /// `null` when that can't be read.
  Future<PushMessage?> initialMessage();
}

/// [PushMessaging] for builds without Firebase settings, and for the platforms
/// Kinvo doesn't send to: nothing is ever allowed, sent or received.
final class UnavailablePushMessaging implements PushMessaging {
  const UnavailablePushMessaging();

  @override
  bool get isAvailable => false;

  @override
  Future<PushPermission> permission() async => PushPermission.blocked;

  @override
  Future<PushPermission> requestPermission() async => PushPermission.blocked;

  @override
  Future<String?> token() async => null;

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();

  @override
  Future<void> deleteToken() async {}

  @override
  Stream<PushMessage> get foregroundMessages => const Stream.empty();

  @override
  Stream<PushMessage> get openedMessages => const Stream.empty();

  @override
  Future<PushMessage?> initialMessage() async => null;
}
