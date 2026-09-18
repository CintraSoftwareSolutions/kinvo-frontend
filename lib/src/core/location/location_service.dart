import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'geo_point.dart';

/// What happened when the app looked for the device's location.
@immutable
sealed class LocationResult {
  const LocationResult();
}

final class LocationFound extends LocationResult {
  const LocationFound({required this.point, this.city, this.countryCode});

  /// Already approximate; see [GeoPoint.approximate].
  final GeoPoint point;

  /// The town or city there, when the device could name it.
  final String? city;

  /// The ISO 3166-1 alpha-2 code of the country there, for example `GB`.
  final String? countryCode;
}

/// The user didn't allow the app to use their location.
final class LocationPermissionDenied extends LocationResult {
  const LocationPermissionDenied({required this.canAskAgain});

  /// False once the system won't ask again, so only the app's settings can
  /// change the answer.
  final bool canAskAgain;
}

/// Location services are switched off for the whole device.
final class LocationServicesDisabled extends LocationResult {
  const LocationServicesDisabled();
}

/// The device couldn't work out where it is, for example indoors without a
/// network fix.
final class LocationUnavailable extends LocationResult {
  const LocationUnavailable();
}

/// Finds roughly where the device is.
abstract interface class LocationService {
  /// Asks for permission if it hasn't been given, then finds the device's
  /// approximate location. Never throws.
  ///
  /// With [askPermission] false, a permission not yet given is reported as
  /// [LocationPermissionDenied] without the system asking, for moments when a
  /// dialog would only get in the way.
  Future<LocationResult> findApproximateLocation({bool askPermission = true});

  /// Opens this app's page in the system settings, where a permission the
  /// system won't ask for again can be granted.
  Future<void> openAppSettings();

  /// Opens the system's location settings.
  Future<void> openLocationSettings();
}

/// Looks up placemarks for a position. The device's geocoder by default.
typedef ReverseGeocoder =
    Future<List<Placemark>> Function(double latitude, double longitude);

final class DeviceLocationService implements LocationService {
  DeviceLocationService({
    GeolocatorPlatform? geolocator,
    ReverseGeocoder? reverseGeocoder,
  }) : _geolocator = geolocator ?? GeolocatorPlatform.instance,
       _reverseGeocoder = reverseGeocoder ?? _deviceReverseGeocoder;

  /// A network fix for an approximate position can be slow, especially
  /// indoors.
  static const positionTimeLimit = Duration(seconds: 20);

  /// Naming the place is a nicety, so it isn't allowed to hold things up.
  static const placeTimeLimit = Duration(seconds: 8);

  /// The backend's limit on a profile's city.
  static const maxCityLength = 120;

  final GeolocatorPlatform _geolocator;
  final ReverseGeocoder _reverseGeocoder;

  @override
  Future<LocationResult> findApproximateLocation({
    bool askPermission = true,
  }) async {
    try {
      if (!await _geolocator.isLocationServiceEnabled()) {
        return const LocationServicesDisabled();
      }

      var permission = await _geolocator.checkPermission();
      if (permission == LocationPermission.denied && askPermission) {
        permission = await _geolocator.requestPermission();
      }
      switch (permission) {
        case LocationPermission.denied:
          return const LocationPermissionDenied(canAskAgain: true);
        case LocationPermission.deniedForever:
          return const LocationPermissionDenied(canAskAgain: false);
        case LocationPermission.unableToDetermine:
          return const LocationUnavailable();
        case LocationPermission.whileInUse || LocationPermission.always:
          break;
      }

      final position = await _approximatePosition();
      if (position == null) return const LocationUnavailable();

      final place = await _placeAt(position.latitude, position.longitude);
      return LocationFound(
        point: GeoPoint.approximate(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
        city: place?.city,
        countryCode: place?.countryCode,
      );
    } on LocationServiceDisabledException {
      return const LocationServicesDisabled();
    } on PermissionDeniedException {
      return const LocationPermissionDenied(canAskAgain: true);
    } on PlatformException catch (error, stackTrace) {
      _log('Could not find the device location.', error, stackTrace);
      return const LocationUnavailable();
    }
  }

  @override
  Future<void> openAppSettings() => _geolocator.openAppSettings();

  @override
  Future<void> openLocationSettings() => _geolocator.openLocationSettings();

  Future<Position?> _approximatePosition() async {
    try {
      return await _geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: positionTimeLimit,
        ),
      );
    } on TimeoutException {
      // A recent position is close enough to find people nearby.
      return _geolocator.getLastKnownPosition();
    }
  }

  Future<({String? city, String? countryCode})?> _placeAt(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await _reverseGeocoder(
        latitude,
        longitude,
      ).timeout(placeTimeLimit);
      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      return (
        city: _cityOf(place),
        countryCode: _countryCodeOf(place.isoCountryCode),
      );
    } on Object catch (error, stackTrace) {
      // Some devices have no geocoder, or no network for it. The position is
      // what matters.
      _log('Could not name the place.', error, stackTrace);
      return null;
    }
  }

  static String? _cityOf(Placemark place) {
    for (final name in [
      place.locality,
      place.subAdministrativeArea,
      place.administrativeArea,
    ]) {
      final trimmed = name?.trim() ?? '';
      if (trimmed.isNotEmpty) {
        return trimmed.length <= maxCityLength
            ? trimmed
            : trimmed.substring(0, maxCityLength);
      }
    }
    return null;
  }

  static String? _countryCodeOf(String? code) {
    final trimmed = code?.trim() ?? '';
    return RegExp(r'^[A-Za-z]{2}$').hasMatch(trimmed)
        ? trimmed.toUpperCase()
        : null;
  }

  static Future<List<Placemark>> _deviceReverseGeocoder(
    double latitude,
    double longitude,
  ) {
    return Geocoding().placemarkFromCoordinates(latitude, longitude);
  }

  static void _log(String message, Object error, StackTrace stackTrace) {
    developer.log(
      message,
      name: 'kinvo.location',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => DeviceLocationService(),
);
