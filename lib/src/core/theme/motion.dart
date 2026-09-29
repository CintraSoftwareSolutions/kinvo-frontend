import 'package:flutter/widgets.dart';

/// Movement, for people who asked for less of it.
extension Motion on BuildContext {
  /// Whether things should keep still here: the phone's setting, or the
  /// account's "Reduce movement", which the app adds to the phone's.
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);

  /// [duration], or no time at all when things should keep still.
  Duration motion(Duration duration) => reduceMotion ? Duration.zero : duration;
}
