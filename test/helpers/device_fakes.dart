import 'package:flutter/foundation.dart';
import 'package:kinvo/src/core/location/geo_point.dart';
import 'package:kinvo/src/core/location/location_service.dart';
import 'package:kinvo/src/core/media/photo_picker.dart';
import 'package:kinvo/src/core/media/photo_processing.dart';

/// A small photo, already prepared, as the picker would return it.
final testPhoto = PreparedPhoto(
  bytes: Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0xDB, 0x00, 0xFF, 0xD9]),
  width: 1200,
  height: 1600,
);

/// Stands in for the camera and photo library.
final class FakePhotoPicker implements PhotoPicker {
  /// What the next pick returns. `null` means the user cancelled.
  PreparedPhoto? nextPhoto = testPhoto;

  /// When set, picking throws this instead.
  PhotoPickException? nextError;

  final List<PhotoSource> requests = [];

  @override
  Future<PreparedPhoto?> pick(PhotoSource source) async {
    requests.add(source);
    if (nextError case final error?) throw error;
    return nextPhoto;
  }
}

/// Stands in for the device's location services.
final class FakeLocationService implements LocationService {
  static const leeds = LocationFound(
    point: GeoPoint(latitude: 53.8, longitude: -1.55),
    city: 'Leeds',
    countryCode: 'GB',
  );

  /// What the next lookup finds.
  LocationResult result = leeds;

  int lookups = 0;
  int appSettingsOpened = 0;
  int locationSettingsOpened = 0;

  @override
  Future<LocationResult> findApproximateLocation({
    bool askPermission = true,
  }) async {
    lookups++;
    return result;
  }

  @override
  Future<void> openAppSettings() async => appSettingsOpened++;

  @override
  Future<void> openLocationSettings() async => locationSettingsOpened++;
}
