import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kinvo/src/core/location/geo_point.dart';
import 'package:kinvo/src/core/location/location_service.dart';

Position _position(double latitude, double longitude) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.utc(2026, 9, 15),
    accuracy: 2000,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

/// A device whose location services answer as each test sets up.
final class _FakeGeolocator extends GeolocatorPlatform {
  bool servicesEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission permissionAfterAsking = LocationPermission.whileInUse;
  Exception? currentPositionError;
  Position current = _position(53.801234, -1.548765);
  Position? lastKnown;

  LocationSettings? requestedSettings;
  int permissionRequests = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => servicesEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return permission = permissionAfterAsking;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    requestedSettings = locationSettings;
    if (currentPositionError case final error?) throw error;
    return current;
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async {
    return lastKnown;
  }
}

void main() {
  late _FakeGeolocator geolocator;
  late List<Placemark> placemarks;
  late Exception? geocoderError;

  DeviceLocationService service() {
    return DeviceLocationService(
      geolocator: geolocator,
      reverseGeocoder: (latitude, longitude) async {
        if (geocoderError case final error?) throw error;
        return placemarks;
      },
    );
  }

  setUp(() {
    geolocator = _FakeGeolocator();
    placemarks = [Placemark(locality: 'Leeds', isoCountryCode: 'gb')];
    geocoderError = null;
  });

  test('finds an approximate position and names the place', () async {
    final result = await service().findApproximateLocation();

    expect(
      result,
      isA<LocationFound>()
          .having(
            (found) => found.point,
            'point',
            const GeoPoint(latitude: 53.8, longitude: -1.55),
          )
          .having((found) => found.city, 'city', 'Leeds')
          .having((found) => found.countryCode, 'countryCode', 'GB'),
    );
    expect(geolocator.requestedSettings?.accuracy, LocationAccuracy.low);
  });

  test('asks for permission when it has not been given yet', () async {
    geolocator.permission = LocationPermission.denied;

    final result = await service().findApproximateLocation();

    expect(geolocator.permissionRequests, 1);
    expect(result, isA<LocationFound>());
  });

  test('reports a refusal, and whether asking again can help', () async {
    geolocator
      ..permission = LocationPermission.denied
      ..permissionAfterAsking = LocationPermission.denied;
    expect(
      await service().findApproximateLocation(),
      isA<LocationPermissionDenied>().having(
        (denied) => denied.canAskAgain,
        'canAskAgain',
        isTrue,
      ),
    );

    geolocator.permission = LocationPermission.deniedForever;
    expect(
      await service().findApproximateLocation(),
      isA<LocationPermissionDenied>().having(
        (denied) => denied.canAskAgain,
        'canAskAgain',
        isFalse,
      ),
    );
  });

  test('reports location services being off', () async {
    geolocator.servicesEnabled = false;

    expect(
      await service().findApproximateLocation(),
      isA<LocationServicesDisabled>(),
    );
  });

  test('falls back to the last known position when a fix is slow', () async {
    geolocator
      ..currentPositionError = TimeoutException('slow')
      ..lastKnown = _position(51.507, -0.128);

    final result = await service().findApproximateLocation();

    expect(
      result,
      isA<LocationFound>().having(
        (found) => found.point,
        'point',
        const GeoPoint(latitude: 51.51, longitude: -0.13),
      ),
    );
  });

  test('reports no location when there is no fix at all', () async {
    geolocator.currentPositionError = TimeoutException('slow');

    expect(
      await service().findApproximateLocation(),
      isA<LocationUnavailable>(),
    );
  });

  test('reports no location when the platform fails', () async {
    geolocator.currentPositionError = PlatformException(code: 'ERROR');

    expect(
      await service().findApproximateLocation(),
      isA<LocationUnavailable>(),
    );
  });

  test('still finds the position when the place cannot be named', () async {
    geocoderError = PlatformException(code: 'IO_ERROR');

    final result = await service().findApproximateLocation();

    expect(
      result,
      isA<LocationFound>()
          .having((found) => found.city, 'city', isNull)
          .having((found) => found.countryCode, 'countryCode', isNull),
    );
  });

  test('names the wider area when the town is unknown', () async {
    placemarks = [
      Placemark(
        subAdministrativeArea: 'West Yorkshire',
        isoCountryCode: 'not-a-code',
      ),
    ];

    final result = await service().findApproximateLocation();

    expect(
      result,
      isA<LocationFound>()
          .having((found) => found.city, 'city', 'West Yorkshire')
          .having((found) => found.countryCode, 'countryCode', isNull),
    );
  });
}
