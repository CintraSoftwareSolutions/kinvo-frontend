import 'package:flutter/foundation.dart';

/// A position on Earth.
@immutable
final class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});

  /// The position rounded to two decimal places, which is about a kilometre.
  ///
  /// Profiles only need to know who is nearby. A precise point, combined with
  /// the distances the app shows between people, could be used to work out
  /// where someone lives.
  factory GeoPoint.approximate({
    required double latitude,
    required double longitude,
  }) {
    return GeoPoint(
      latitude: _roundToHundredths(latitude),
      longitude: _roundToHundredths(longitude),
    );
  }

  final double latitude;
  final double longitude;

  static double _roundToHundredths(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  @override
  bool operator ==(Object other) {
    return other is GeoPoint &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';
}
