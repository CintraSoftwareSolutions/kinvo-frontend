import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import '../../../core/push/push_config.dart';
import '../domain/call.dart';

/// The call screen a closed phone shows: full screen, over the lock screen,
/// with Answer and Decline.
///
/// WHY THIS IS NOT THE APP'S OWN SCREEN. A closed app has nothing running to
/// draw with. Android wakes it for a data-only push, and what runs is this —
/// a separate isolate with no widgets, no providers and no session. All it can
/// do is ask Android to show a call, which Android then draws itself. The app
/// proper only hears about it when the person answers.
///
/// The caller is NOT named here, deliberately. A lock screen is visible to
/// whoever is holding the phone, and this is a dating app; the notification
/// says a Kinvo call is coming, and who it is from appears once the phone is
/// unlocked. That is a product decision and can be reversed in one string.

/// The data key the server sets on every notification.
const _categoryKey = 'category';
const _callCategory = 'call';

/// Shows the incoming call, or does nothing for any other notification.
///
/// Returns true when it took the message, so the caller knows not to treat it
/// as an ordinary banner.
Future<bool> showIncomingCallFromPush(Map<String, String> data) async {
  if (data[_categoryKey] != _callCategory) return false;

  final callId = data['call_id'];
  if (callId == null || callId.isEmpty) return false;

  final kind = CallKind.fromWireValue(data['kind'] ?? 'video');

  await FlutterCallkitIncoming.showCallkitIncoming(
    CallKitParams(
      id: callId,
      nameCaller: 'Kinvo',
      appName: 'Kinvo',
      handle: kind == CallKind.audio ? 'Voice call' : 'Video call',
      type: kind == CallKind.audio ? 0 : 1,
      // Matches the app's own timeout, so a phone does not keep ringing for a
      // call the server has already written off as missed.
      duration: 60000,
      // Handed back untouched when the person answers, which is how the app
      // knows which call to pick up after being launched by the notification.
      extra: {'call_id': callId, 'kind': kind.wireValue},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        textAccept: 'Answer',
        textDecline: 'Decline',
        // Over the lock screen, which is the whole point: a phone in a pocket
        // must show the call without being unlocked first.
        isShowFullLockedScreen: true,
        isImportant: true,
        // The phone's own ringtone: the chooser in Settings changes what the
        // app plays while it is open, and Android decides this one.
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#6F47CB',
        actionColor: '#15B887',
        incomingCallNotificationChannelName: 'Incoming calls',
      ),
      ios: const IOSParams(handleType: 'generic', supportsVideo: true),
    ),
  );

  return true;
}

/// Takes the call screen away — answered elsewhere, cancelled, or rung out.
Future<void> hideIncomingCall(String callId) async {
  try {
    await FlutterCallkitIncoming.endCall(callId);
  } on Object catch (error, stackTrace) {
    developer.log(
      'Could not close the incoming call notification.',
      name: 'kinvo.calls',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Runs in its own isolate when a push arrives at a phone whose app is closed.
///
/// Top-level and annotated on purpose: Flutter looks this function up by name
/// to start the isolate, so it cannot be a method or a closure.
///
/// Nothing here may assume the app is running. Firebase is started again
/// because this isolate has its own memory, and everything is wrapped: a
/// failure in the background is invisible to the user, so it must never
/// become a crash loop.
@pragma('vm:entry-point')
Future<void> handleBackgroundPush(RemoteMessage message) async {
  try {
    final config = PushConfig.fromEnvironment();
    final options = config?.optionsFor(defaultTargetPlatform);
    if (options == null) return;

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: options);
    }

    await showIncomingCallFromPush(Map<String, String>.from(message.data));
  } on Object catch (error, stackTrace) {
    developer.log(
      'A push could not be handled in the background.',
      name: 'kinvo.push',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
