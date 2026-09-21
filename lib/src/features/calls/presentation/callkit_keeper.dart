import 'dart:async';

import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/push/push_providers.dart';
import 'controllers/call_controller.dart';

/// Answers and declines that came from the lock screen.
///
/// The call screen a closed phone shows is drawn by Android, not by this app
/// (see `incoming_call_notification.dart`). When the person taps Answer or
/// Decline there, this is what hears about it: the app has been launched or
/// brought back by then, so it can tell the server.
///
/// Listen to this once, for as long as the app runs.
final callkitKeeperProvider = Provider<void>((ref) {
  // Nothing to listen to in a build without push, which is also every test.
  if (!ref.watch(pushMessagingProvider).isAvailable) return;

  final events = FlutterCallkitIncoming.onEvent.listen((event) {
    final calls = ref.read(callControllerProvider.notifier);

    switch (event) {
      case CallEventActionCallAccept(:final callKitParams):
        if (_idOf(callKitParams) case final callId?) {
          unawaited(calls.answerFromNotification(callId));
        }
      case CallEventActionCallDecline(:final callKitParams):
        if (_idOf(callKitParams) case final callId?) {
          unawaited(calls.declineFromNotification(callId));
        }
      case CallEventActionCallEnded(:final callKitParams):
        if (_idOf(callKitParams) case final callId?) {
          unawaited(calls.endFromNotification(callId));
        }
      case CallEventActionCallTimeout():
        // Rang out. The server writes it off as missed at the same moment, so
        // there is nothing to tell it: the screen simply goes.
        break;
      case _:
        break;
    }
  });

  ref.onDispose(() => unawaited(events.cancel()));
});

/// The call an event is about. The id is what the notification was shown with.
String? _idOf(CallKitParams params) {
  if (params.id.isNotEmpty) return params.id;

  final extra = params.extra?['call_id'];
  return extra is String && extra.isNotEmpty ? extra : null;
}
