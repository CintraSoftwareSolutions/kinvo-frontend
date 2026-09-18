import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app's snackbar messenger, for messages that don't belong to one
/// screen, such as a notification arriving or the session ending.
final appMessengerKeyProvider = Provider<GlobalKey<ScaffoldMessengerState>>(
  (ref) => GlobalKey(debugLabel: 'app messenger'),
);
