import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/push/push_providers.dart';

/// What someone did on the call screen the phone drew for itself.
enum CallNotificationAction { answer, decline, end }

/// One of those, and the call it was about.
@immutable
final class CallNotificationEvent {
  const CallNotificationEvent({required this.callId, required this.action});

  final String callId;
  final CallNotificationAction action;
}

/// The call screen a closed phone shows, and what comes back from it.
///
/// An interface for the same reason the video service has one: this is the
/// only file that knows which package draws that screen, and a flow that can
/// only be exercised on a real locked phone is one that must be testable
/// without one.
abstract interface class CallNotifications {
  /// False where no call can arrive — a build with no push settings, and
  /// every test that does not ask for one.
  bool get isAvailable;

  /// Answers, declines and hang-ups from the phone's own call screen.
  ///
  /// Nothing is replayed: an action taken before the app was listening is
  /// gone from here, which is what [acceptedCalls] exists to recover.
  Stream<CallNotificationEvent> get actions;

  /// Calls this phone has already accepted and not finished with.
  ///
  /// THE POINT OF THIS. When the phone is asleep the app is not running, so
  /// answering starts it — and the answer itself happened seconds before
  /// there was anything to hear it. The platform remembers it; this is how
  /// the app finds out, once it exists.
  Future<List<String>> acceptedCalls();

  /// Turns the incoming call the phone is showing into an ongoing one, so its
  /// notification stops offering to answer a call that has been answered.
  Future<void> markConnected(String callId);

  /// Takes the call screen away — answered elsewhere, declined, or over.
  ///
  /// Also what clears the platform's memory of the call, so [acceptedCalls]
  /// cannot hand back the same finished call at the next launch.
  Future<void> hide(String callId);
}

/// [CallNotifications] on `flutter_callkit_incoming`.
final class CallkitNotifications implements CallNotifications {
  const CallkitNotifications();

  @override
  bool get isAvailable => true;

  @override
  Stream<CallNotificationEvent> get actions {
    return FlutterCallkitIncoming.onEvent
        .map(_eventFrom)
        .where((event) => event != null)
        .cast<CallNotificationEvent>();
  }

  @override
  Future<List<String>> acceptedCalls() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      return [
        for (final call in calls)
          if (call.isAccepted) ?idOf(call),
      ];
    } on Object catch (error, stackTrace) {
      _log(
        'Could not read the calls this phone has accepted.',
        error,
        stackTrace,
      );
      return const [];
    }
  }

  @override
  Future<void> markConnected(String callId) async {
    try {
      await FlutterCallkitIncoming.setCallConnected(callId);
    } on Object catch (error, stackTrace) {
      // Nothing about the call itself depends on this: it is the phone's own
      // notification catching up with what already happened.
      _log('Could not mark the call connected.', error, stackTrace);
    }
  }

  @override
  Future<void> hide(String callId) async {
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } on Object catch (error, stackTrace) {
      _log(
        'Could not close the incoming call notification.',
        error,
        stackTrace,
      );
    }
  }

  /// The call an event is about. The id is what the notification was shown
  /// with; `extra` carries it too, for a platform that hands back its own.
  @visibleForTesting
  static String? idOf(CallKitParams params) {
    if (params.id.isNotEmpty) return params.id;

    final extra = params.extra?['call_id'];
    return extra is String && extra.isNotEmpty ? extra : null;
  }

  static CallNotificationEvent? _eventFrom(CallEvent? event) {
    final CallKitParams params;
    final CallNotificationAction action;

    switch (event) {
      case CallEventActionCallAccept(:final callKitParams):
        params = callKitParams;
        action = CallNotificationAction.answer;
      case CallEventActionCallDecline(:final callKitParams):
        params = callKitParams;
        action = CallNotificationAction.decline;
      case CallEventActionCallEnded(:final callKitParams):
        params = callKitParams;
        action = CallNotificationAction.end;
      default:
        // Everything else is not an action on a call: ringing out is written
        // off as missed by the server at the same moment, and the rest are
        // iPhone controls the app does not use.
        return null;
    }

    final callId = idOf(params);
    return callId == null
        ? null
        : CallNotificationEvent(callId: callId, action: action);
  }

  static void _log(String message, Object error, StackTrace stackTrace) {
    developer.log(
      message,
      name: 'kinvo.calls',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// What a build with no push settings gets: a phone that never rings for a
/// call, and an app that never waits for one.
final class NoCallNotifications implements CallNotifications {
  const NoCallNotifications();

  @override
  bool get isAvailable => false;

  @override
  Stream<CallNotificationEvent> get actions => const Stream.empty();

  @override
  Future<List<String>> acceptedCalls() async => const [];

  @override
  Future<void> markConnected(String callId) async {}

  @override
  Future<void> hide(String callId) async {}
}

/// The call screen the phone draws: the real one where push works, and
/// nothing anywhere else. Tests replace it.
final callNotificationsProvider = Provider<CallNotifications>((ref) {
  if (!ref.watch(pushMessagingProvider).isAvailable) {
    return const NoCallNotifications();
  }
  return const CallkitNotifications();
});
