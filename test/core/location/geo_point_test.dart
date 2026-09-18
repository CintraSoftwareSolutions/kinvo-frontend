import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/location/geo_point.dart';

void main() {
  test('an approximate point is rounded to about a kilometre', () {
    final point = GeoPoint.approximate(
      latitude: 53.801234,
      longitude: -1.548765,
    );

    expect(point, const GeoPoint(latitude: 53.8, longitude: -1.55));
  });

  test('rounding works on both sides of zero', () {
    expect(
      GeoPoint.approximate(latitude: -33.8688, longitude: 151.2093),
      const GeoPoint(latitude: -33.87, longitude: 151.21),
    );
    expect(
      GeoPoint.approximate(latitude: 0.004, longitude: -0.006),
      const GeoPoint(latitude: 0, longitude: -0.01),
    );
  });
}
