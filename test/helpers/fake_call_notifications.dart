import 'dart:async';

import 'package:kinvo/src/features/calls/presentation/call_notifications.dart';

/// The call screen a phone draws for itself, as a test can drive it.
///
/// The real one only exists on a locked Android phone, which is exactly why
/// the app talks to it through an interface: answering a call on a sleeping
/// phone is the path most likely to break and the hardest to reach by hand.
final class FakeCallNotifications implements CallNotifications {
  FakeCallNotifications({this.available = true});

  final bool available;

  /// Calls the phone says it has already accepted, as it would after being
  /// answered on the lock screen of a phone whose app was not running.
  List<String> accepted = [];

  /// Calls the app asked to take off the screen, and calls it said are now
  /// connected, in order.
  final List<String> hidden = [];
  final List<String> connected = [];

  final _actions = StreamController<CallNotificationEvent>.broadcast();

  @override
  bool get isAvailable => available;

  @override
  Stream<CallNotificationEvent> get actions => _actions.stream;

  @override
  Future<List<String>> acceptedCalls() async => accepted;

  @override
  Future<void> markConnected(String callId) async => connected.add(callId);

  @override
  Future<void> hide(String callId) async => hidden.add(callId);

  /// Somebody pressing Answer, Decline or the hang-up on the phone's own call
  /// screen while the app is running.
  void tap(CallNotificationAction action, String callId) {
    _actions.add(CallNotificationEvent(callId: callId, action: action));
  }

  Future<void> close() => _actions.close();
}
