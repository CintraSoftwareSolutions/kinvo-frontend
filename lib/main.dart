import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/core/network/api_retry_policy.dart';
import 'src/core/push/push_config.dart';
import 'src/features/calls/presentation/incoming_call_notification.dart';

void main() {
  // Registered before anything else runs, because Android calls it on a phone
  // whose app is closed — that is how an incoming call rings a phone in a
  // pocket. It does nothing in a build with no Firebase settings.
  if (PushConfig.fromEnvironment() != null) {
    WidgetsFlutterBinding.ensureInitialized();
    FirebaseMessaging.onBackgroundMessage(handleBackgroundPush);
  }

  runApp(const ProviderScope(retry: apiRetryPolicy, child: KinvoApp()));
}
