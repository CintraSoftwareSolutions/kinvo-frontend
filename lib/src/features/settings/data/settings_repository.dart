import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/units/distance.dart';
import '../domain/signed_in_device.dart';
import '../domain/user_settings.dart';

/// The signed-in user's settings.
///
/// Failures are `ApiException`s.
abstract interface class SettingsRepository {
  Future<UserSettings> fetchSettings();

  /// Changes the settings given and leaves the rest alone.
  Future<UserSettings> update({
    DistanceUnit? distanceUnit,
    bool? showDistance,
    bool? showLastActive,
    AppThemeChoice? theme,
    double? textScale,
    bool? reduceMotion,
    bool? highContrast,
    bool? incognito,
    bool? verifiedOnlyEverywhere,
    bool? pauseNewMatches,
  });

  /// Hides the user from Discover until [until], or until they come back when
  /// it's `null`. Matches and chats carry on.
  Future<UserSettings> takeBreak({DateTime? until});

  /// Shows the user in Discover again.
  Future<UserSettings> endBreak();
}

/// [SettingsRepository] on the Kinvo API.
final class ApiSettingsRepository implements SettingsRepository {
  const ApiSettingsRepository(this._api);

  final ApiClient _api;

  @override
  Future<UserSettings> fetchSettings() {
    return _api.get('/settings', decode: UserSettings.fromJson);
  }

  @override
  Future<UserSettings> update({
    DistanceUnit? distanceUnit,
    bool? showDistance,
    bool? showLastActive,
    AppThemeChoice? theme,
    double? textScale,
    bool? reduceMotion,
    bool? highContrast,
    bool? incognito,
    bool? verifiedOnlyEverywhere,
    bool? pauseNewMatches,
  }) {
    final body = {
      'distance_unit': ?distanceUnit?.wireValue,
      'show_distance': ?showDistance,
      'show_last_active': ?showLastActive,
      'theme': ?theme?.wireValue,
      'text_scale': ?textScale,
      'reduce_motion': ?reduceMotion,
      'high_contrast': ?highContrast,
      'incognito': ?incognito,
      'global_verified_only': ?verifiedOnlyEverywhere,
      'pause_new_matches': ?pauseNewMatches,
    };
    if (body.isEmpty) {
      throw ArgumentError('Give at least one setting to change.');
    }
    return _api.patch('/settings', body: body, decode: UserSettings.fromJson);
  }

  @override
  Future<UserSettings> takeBreak({DateTime? until}) {
    return _api.post(
      '/settings/snooze',
      body: {'ends_at': ?until?.toUtc().toIso8601String()},
      decode: UserSettings.fromJson,
    );
  }

  @override
  Future<UserSettings> endBreak() {
    return _api.delete('/settings/snooze', decode: UserSettings.fromJson);
  }
}

/// The phones and tablets signed in to the account.
abstract interface class DevicesRepository {
  /// Most recently used first.
  Future<List<SignedInDevice>> fetchDevices();

  /// Signs the device with list entry [deviceId] out. It stops working
  /// straight away.
  Future<void> signOut(String deviceId);

  /// Signs out every device except this one. Returns how many were.
  Future<int> signOutOthers();
}

/// [DevicesRepository] on the Kinvo API.
final class ApiDevicesRepository implements DevicesRepository {
  const ApiDevicesRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<SignedInDevice>> fetchDevices() {
    return _api.get('/devices', decode: _readDevices);
  }

  @override
  Future<void> signOut(String deviceId) {
    return _api.delete(
      '/devices/${Uri.encodeComponent(deviceId)}',
      decode: ApiClient.ignoreData,
    );
  }

  @override
  Future<int> signOutOthers() {
    return _api.delete('/devices/others', decode: _readCount);
  }

  static List<SignedInDevice> _readDevices(JsonMap json) {
    if (json case {'devices': final List<Object?> devices}) {
      return [
        for (final device in devices) ?SignedInDevice.tryFromJson(device),
      ];
    }
    throw const FormatException('Expected devices.');
  }

  static int _readCount(JsonMap json) {
    if (json case {'revoked_count': final int count} when count >= 0) {
      return count;
    }
    throw const FormatException('Expected a non-negative revoked_count.');
  }
}

/// The repository settings use.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return ApiSettingsRepository(ref.watch(apiClientProvider));
});

/// The repository the device list uses.
final devicesRepositoryProvider = Provider<DevicesRepository>((ref) {
  return ApiDevicesRepository(ref.watch(apiClientProvider));
});
