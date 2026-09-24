import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/session_status.dart';
import 'call_notifications.dart';
import 'controllers/call_controller.dart';

/// Answers and declines that came from the phone's own call screen.
///
/// The screen a closed phone shows is drawn by Android, not by this app (see
/// `incoming_call_notification.dart`). This is what hears what was done on it,
/// in the two ways that can happen:
///
/// 1. **The app was running.** The answer arrives as an event, and is acted on
///    at once.
/// 2. **The app was not.** Answering is what started it, so the event was
///    raised before there was anything to hear it — and events are not
///    replayed. The platform remembers the call instead, and the app asks for
///    it as soon as it can. Without this second path, answering a call on a
///    sleeping phone opened Kinvo and nothing else happened, which is exactly
///    what it looked like.
///
/// Listen to this once, for as long as the app runs.
final callkitKeeperProvider = Provider<void>((ref) {
  final notifications = ref.watch(callNotificationsProvider);
  // Nothing can arrive in a build without push, which is also every test that
  // does not ask for it.
  if (!notifications.isAvailable) return;

  final events = notifications.actions.listen((event) {
    final calls = ref.read(callControllerProvider.notifier);

    switch (event.action) {
      case CallNotificationAction.answer:
        unawaited(calls.answerFromNotification(event.callId));
      case CallNotificationAction.decline:
        unawaited(calls.declineFromNotification(event.callId));
      case CallNotificationAction.end:
        unawaited(calls.endFromNotification(event.callId));
    }
  });

  ref.onDispose(() => unawaited(events.cancel()));

  unawaited(_answerWhatThePhoneAlreadyAccepted(ref, notifications));
});

/// Picks up a call answered on the lock screen of a phone whose app was not
/// running.
///
/// The session comes first: this runs while the saved one is still being read,
/// and answering without it would be a request with no account behind it,
/// which the server refuses and the person reads as a call that did not work.
Future<void> _answerWhatThePhoneAlreadyAccepted(
  Ref ref,
  CallNotifications notifications,
) async {
  final accepted = await notifications.acceptedCalls();
  if (accepted.isEmpty || !ref.mounted) return;

  await ref.read(sessionManagerProvider).ready;
  if (!ref.mounted) return;

  if (ref.read(sessionStatusProvider) is! SignedIn) {
    // Answered by somebody who is not signed in — a session that ended while
    // the phone was asleep. The call cannot be joined, so the screen the
    // phone is still showing is taken away rather than left ringing.
    for (final callId in accepted) {
      await notifications.hide(callId);
    }
    return;
  }

  final calls = ref.read(callControllerProvider.notifier);
  for (final callId in accepted) {
    if (!ref.mounted) return;
    await calls.answerFromNotification(callId);
  }
}
