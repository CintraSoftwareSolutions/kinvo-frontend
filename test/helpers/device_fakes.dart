import 'dart:convert';

import 'package:kinvo/src/core/location/geo_point.dart';
import 'package:kinvo/src/core/location/location_service.dart';
import 'package:kinvo/src/core/auth/google_identity.dart';
import 'package:kinvo/src/core/media/photo_picker.dart';
import 'package:kinvo/src/core/media/photo_processing.dart';

/// A small photo, already prepared, as the picker would return it.
///
/// Real JPEG bytes, not a stub: a screen that shows the picture back — the
/// verification capture screen does — decodes them, and a decoder cannot be
/// fooled by seven bytes that merely start like a JPEG.
final testPhoto = PreparedPhoto(
  bytes: base64Decode(
    '/9j/4AAQSkZJRgABAQAAAQABAAD/2wCEAA0JCgsKCA0LCgsODg0PEyAVExISEyccHhcgLikxMC4pLSwzOko+MzZGNywtQFdBRkxOUlNSMj5aYVpQYEpRUk8BDg4OExETJhUVJk81LTVPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT//AABEIAAIAAgMBEQACEQEDEQH/xAGiAAABBQEBAQEBAQAAAAAAAAAAAQIDBAUGBwgJCgsQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+gEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoLEQACAQIEBAMEBwUEBAABAncAAQIDEQQFITEGEkFRB2FxEyIygQgUQpGhscEJIzNS8BVictEKFiQ04SXxFxgZGiYnKCkqNTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqCg4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2dri4+Tl5ufo6ery8/T19vf4+fr/2gAMAwEAAhEDEQA/AG19ObH/2Q==',
  ),
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

/// Stands in for Google's own sign-in screen.
final class FakeGoogleIdentity implements GoogleIdentity {
  /// Whether the build offers Google at all.
  bool available = true;

  /// Who comes back from Google. `null` means the person backed out.
  GoogleAccount? nextAccount = const GoogleAccount(
    idToken: 'google-id-token',
    displayName: 'Sam Google',
  );

  /// When set, signing in throws this instead.
  GoogleSignInRefused? nextRefusal;

  int signInCount = 0;
  int signOutCount = 0;

  @override
  bool get isAvailable => available;

  @override
  Future<GoogleAccount?> signIn() async {
    signInCount++;
    if (nextRefusal case final refusal?) throw refusal;
    return nextAccount;
  }

  @override
  Future<void> signOut() async => signOutCount++;
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
