import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Returns the current time.
typedef Clock = DateTime Function();

/// The time the app runs on. Tests override it to fix today's date.
final clockProvider = Provider<Clock>((ref) => DateTime.now);
