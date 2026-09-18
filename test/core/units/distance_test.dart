import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/units/distance.dart';

void main() {
  test('reads the settings value of each unit', () {
    expect(DistanceUnit.fromWire('miles'), DistanceUnit.miles);
    expect(DistanceUnit.fromWire('kilometres'), DistanceUnit.kilometres);
    expect(DistanceUnit.fromWire('leagues'), isNull);
  });

  group('distanceAway', () {
    test('rounds to whole miles and never gets more precise', () {
      expect(distanceAway(null, DistanceUnit.miles), isNull);
      expect(distanceAway(-1, DistanceUnit.miles), isNull);
      expect(distanceAway(400, DistanceUnit.miles), 'Less than a mile away');
      expect(distanceAway(1609.344, DistanceUnit.miles), '1 mile away');
      expect(distanceAway(6437, DistanceUnit.miles), '4 miles away');
    });

    test('rounds to whole kilometres the same way', () {
      expect(distanceAway(400, DistanceUnit.kilometres), 'Less than 1 km away');
      expect(distanceAway(1000, DistanceUnit.kilometres), '1 km away');
      expect(distanceAway(6437, DistanceUnit.kilometres), '6 km away');
    });
  });

  group('radius', () {
    test('converts between the filters and the API in either unit', () {
      expect(DistanceUnit.miles.toMetres(30), 48280);
      expect(DistanceUnit.miles.fromMetres(48280), 30);
      expect(DistanceUnit.kilometres.toMetres(40), 40000);
      expect(DistanceUnit.kilometres.fromMetres(48280), 48);
      expect(radiusLabel(1609, DistanceUnit.miles), '1 mile');
      expect(radiusLabel(80467, DistanceUnit.miles), '50 miles');
      expect(radiusLabel(80467, DistanceUnit.kilometres), '80 km');
    });

    test('never offers a radius past the 500 km the server accepts', () {
      for (final unit in DistanceUnit.values) {
        expect(
          unit.toMetres(unit.radiusStops.last),
          lessThanOrEqualTo(500000),
          reason: unit.name,
        );
      }
    });
  });
}
