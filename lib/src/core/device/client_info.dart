import 'dart:developer' as developer;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../storage/key_value_store.dart';

/// The operating systems the backend tells apart.
enum ClientPlatform {
  android('android'),
  ios('ios');

  const ClientPlatform(this.wireValue);

  /// The value sent in the `X-Platform` header.
  final String wireValue;

  static ClientPlatform? fromTargetPlatform(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => null,
    };
  }
}

/// Identifies this installation of the app to the backend.
@immutable
final class ClientInfo {
  const ClientInfo({
    required this.deviceId,
    required this.platform,
    required this.appVersion,
    this.deviceModel,
    this.osVersion,
  });

  /// Random id for this installation. The backend ties sessions and push
  /// tokens to it, so it stays the same across launches.
  final String deviceId;

  /// `null` on platforms the backend doesn't distinguish.
  final ClientPlatform? platform;

  /// Version and build number, for example `1.0.0+1`.
  final String appVersion;

  /// The phone's make and model, such as "Google Pixel 8", so the user can
  /// tell their devices apart in Settings. `null` when it can't be read.
  final String? deviceModel;

  /// Such as "Android 15" or "iOS 18.1". `null` when it can't be read.
  final String? osVersion;
}

/// What the device list says about this device.
@immutable
final class DeviceDescription {
  const DeviceDescription({this.model, this.osVersion});

  final String? model;
  final String? osVersion;
}

/// Describes the device the app runs on, from the operating system.
Future<DeviceDescription?> describeThisDevice(TargetPlatform platform) async {
  final plugin = DeviceInfoPlugin();
  switch (platform) {
    case TargetPlatform.android:
      final android = await plugin.androidInfo;
      return DeviceDescription(
        model: androidModelName(android.manufacturer, android.model),
        osVersion: 'Android ${android.version.release}',
      );
    case TargetPlatform.iOS:
      final ios = await plugin.iosInfo;
      return DeviceDescription(
        model: ios.modelName,
        osVersion: '${ios.systemName} ${ios.systemVersion}',
      );
    case _:
      return null;
  }
}

/// An Android phone's name as people know it: "Google Pixel 8", or
/// "Samsung SM-S918B" when the model doesn't already start with the maker.
@visibleForTesting
String androidModelName(String manufacturer, String model) {
  final maker = manufacturer.trim();
  final name = model.trim();
  if (maker.isEmpty || name.toLowerCase().startsWith(maker.toLowerCase())) {
    return name;
  }
  return '${maker[0].toUpperCase()}${maker.substring(1)} $name';
}

/// Loads [ClientInfo], creating the device id on first launch.
final class ClientInfoLoader {
  ClientInfoLoader({
    required KeyValueStore preferences,
    Future<PackageInfo> Function()? packageInfo,
    TargetPlatform? platform,
    String Function()? generateDeviceId,
    Future<DeviceDescription?> Function(TargetPlatform)? describeDevice,
  }) : _preferences = preferences,
       _packageInfo = packageInfo ?? PackageInfo.fromPlatform,
       _platform = platform ?? defaultTargetPlatform,
       _generateDeviceId = generateDeviceId ?? const Uuid().v4,
       _describeDevice = describeDevice ?? describeThisDevice;

  static const deviceIdKey = 'kinvo.device_id';

  /// Column limits in the backend's `devices` table.
  static const maxDeviceIdLength = 128;
  static const maxAppVersionLength = 32;
  static const maxDeviceModelLength = 64;
  static const maxOsVersionLength = 32;

  final KeyValueStore _preferences;
  final Future<PackageInfo> Function() _packageInfo;
  final TargetPlatform _platform;
  final String Function() _generateDeviceId;
  final Future<DeviceDescription?> Function(TargetPlatform) _describeDevice;

  /// Never throws. When storage fails, this launch uses a new device id rather
  /// than blocking every request.
  Future<ClientInfo> load() async {
    final (deviceId, appVersion, description) = await (
      _loadDeviceId(),
      _loadAppVersion(),
      _loadDescription(),
    ).wait;
    return ClientInfo(
      deviceId: deviceId,
      platform: ClientPlatform.fromTargetPlatform(_platform),
      appVersion: appVersion,
      deviceModel: _fitted(description?.model, maxDeviceModelLength),
      osVersion: _fitted(description?.osVersion, maxOsVersionLength),
    );
  }

  /// Only labels the device list, so a failure just leaves it out.
  Future<DeviceDescription?> _loadDescription() async {
    try {
      return await _describeDevice(_platform);
    } on Object catch (error, stackTrace) {
      _log('Could not describe the device.', error, stackTrace);
      return null;
    }
  }

  static String? _fitted(String? value, int maxLength) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return trimmed.length <= maxLength
        ? trimmed
        : trimmed.substring(0, maxLength);
  }

  Future<String> _loadDeviceId() async {
    try {
      final stored = await _preferences.read(deviceIdKey);
      if (stored != null &&
          stored.isNotEmpty &&
          stored.length <= maxDeviceIdLength) {
        return stored;
      }
    } on Object catch (error, stackTrace) {
      _log('Could not read the device id.', error, stackTrace);
    }

    final created = _generateDeviceId();
    try {
      await _preferences.write(deviceIdKey, created);
    } on Object catch (error, stackTrace) {
      _log(
        'Could not save the device id; the next launch will use a new one.',
        error,
        stackTrace,
      );
    }
    return created;
  }

  Future<String> _loadAppVersion() async {
    try {
      final info = await _packageInfo();
      final version = info.buildNumber.isEmpty
          ? info.version
          : '${info.version}+${info.buildNumber}';
      return version.length <= maxAppVersionLength
          ? version
          : version.substring(0, maxAppVersionLength);
    } on Object catch (error, stackTrace) {
      _log('Could not read the app version.', error, stackTrace);
      return 'unknown';
    }
  }

  static void _log(String message, Object error, StackTrace stackTrace) {
    developer.log(
      message,
      name: 'kinvo.device',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
