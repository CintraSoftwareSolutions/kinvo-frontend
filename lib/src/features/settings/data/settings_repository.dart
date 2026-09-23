import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo/demo_mode.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/time/clock.dart';
import '../../../core/units/distance.dart';
import '../domain/signed_in_device.dart';
import '../domain/user_settings.dart';

/// The signed-in user's settings.
///
/// An interface because the demo shows the same screens without an account,
/// on [DemoSettingsRepository]. Failures are `ApiException`s.
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
  }) {
    final body = {
      'distance_unit': ?distanceUnit?.wireValue,
      'show_distance': ?showDistance,
      'show_last_active': ?showLastActive,
      'theme': ?theme?.wireValue,
      'text_scale': ?textScale,
      'reduce_motion': ?reduceMotion,
      'high_contrast': ?highContrast,
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
///
/// An interface for the demo, as [SettingsRepository] is.
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

/// The demo's settings and devices, kept for as long as the demo runs.
final class DemoSettings {
  DemoSettings({required Clock clock})
    : devices = [
        SignedInDevice(
          id: 'demo-this-device',
          platform: 'android',
          model: 'This phone',
          isCurrent: true,
          lastSeenAt: clock(),
        ),
        SignedInDevice(
          id: 'demo-tablet',
          platform: 'ios',
          model: 'iPad Air',
          osVersion: 'iPadOS 18.1',
          appVersion: '1.0.0+1',
          isCurrent: false,
          lastSeenAt: clock().subtract(const Duration(days: 3)),
        ),
        SignedInDevice(
          id: 'demo-old-phone',
          platform: 'android',
          model: 'Google Pixel 6',
          osVersion: 'Android 14',
          appVersion: '1.0.0+1',
          isCurrent: false,
          lastSeenAt: clock().subtract(const Duration(days: 40)),
        ),
      ];

  UserSettings settings = UserSettings.defaults;
  final List<SignedInDevice> devices;
}

final demoSettingsProvider = Provider<DemoSettings>((ref) {
  ref.watch(demoSessionProvider);
  return DemoSettings(clock: ref.watch(clockProvider));
});

/// [SettingsRepository] for the demo: settings are kept in [DemoSettings],
/// and nothing is sent anywhere.
final class DemoSettingsRepository implements SettingsRepository {
  const DemoSettingsRepository(this._demo);

  final DemoSettings _demo;

  @override
  Future<UserSettings> fetchSettings() async => _demo.settings;

  @override
  Future<UserSettings> update({
    DistanceUnit? distanceUnit,
    bool? showDistance,
    bool? showLastActive,
    AppThemeChoice? theme,
    double? textScale,
    bool? reduceMotion,
    bool? highContrast,
  }) async {
    return _demo.settings = _demo.settings.copyWith(
      distanceUnit: distanceUnit,
      showDistance: showDistance,
      showLastActive: showLastActive,
      theme: theme,
      textScale: textScale,
      reduceMotion: reduceMotion,
      highContrast: highContrast,
    );
  }

  @override
  Future<UserSettings> takeBreak({DateTime? until}) async {
    final settings = _demo.settings;
    return _demo.settings = UserSettings(
      distanceUnit: settings.distanceUnit,
      showDistance: settings.showDistance,
      showLastActive: settings.showLastActive,
      snooze: Snooze(endsAt: until),
    );
  }

  @override
  Future<UserSettings> endBreak() async {
    final settings = _demo.settings;
    return _demo.settings = UserSettings(
      distanceUnit: settings.distanceUnit,
      showDistance: settings.showDistance,
      showLastActive: settings.showLastActive,
    );
  }
}

/// [DevicesRepository] for the demo, over [DemoSettings.devices].
final class DemoDevicesRepository implements DevicesRepository {
  const DemoDevicesRepository(this._demo);

  final DemoSettings _demo;

  @override
  Future<List<SignedInDevice>> fetchDevices() async => [..._demo.devices];

  @override
  Future<void> signOut(String deviceId) async {
    _demo.devices.removeWhere((device) => device.id == deviceId);
  }

  @override
  Future<int> signOutOthers() async {
    final before = _demo.devices.length;
    _demo.devices.removeWhere((device) => !device.isCurrent);
    return before - _demo.devices.length;
  }
}

/// The repository settings use: the demo's while exploring it, the API's
/// otherwise.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  if (ref.watch(demoSessionProvider)) {
    return DemoSettingsRepository(ref.watch(demoSettingsProvider));
  }
  return ApiSettingsRepository(ref.watch(apiClientProvider));
});

/// The repository the device list uses: the demo's while exploring it, the
/// API's otherwise.
final devicesRepositoryProvider = Provider<DevicesRepository>((ref) {
  if (ref.watch(demoSessionProvider)) {
    return DemoDevicesRepository(ref.watch(demoSettingsProvider));
  }
  return ApiDevicesRepository(ref.watch(apiClientProvider));
});
