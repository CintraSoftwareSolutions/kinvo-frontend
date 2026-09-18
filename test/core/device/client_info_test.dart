import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/device/client_info.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../helpers/in_memory_key_value_store.dart';

PackageInfo _packageInfo({String version = '1.4.0', String buildNumber = '7'}) {
  return PackageInfo(
    appName: 'Kinvo',
    packageName: 'com.example.kinvo',
    version: version,
    buildNumber: buildNumber,
  );
}

void main() {
  late InMemoryKeyValueStore preferences;
  var generatedIds = 0;

  ClientInfoLoader loader({
    Future<PackageInfo> Function()? packageInfo,
    TargetPlatform platform = TargetPlatform.android,
    Future<DeviceDescription?> Function(TargetPlatform)? describeDevice,
  }) {
    return ClientInfoLoader(
      preferences: preferences,
      packageInfo: packageInfo ?? () async => _packageInfo(),
      platform: platform,
      generateDeviceId: () => 'device-${++generatedIds}',
      describeDevice:
          describeDevice ??
          (_) async => const DeviceDescription(
            model: 'Google Pixel 8',
            osVersion: 'Android 15',
          ),
    );
  }

  setUp(() {
    preferences = InMemoryKeyValueStore();
    generatedIds = 0;
  });

  group('device id', () {
    test('is created on first launch and reused afterwards', () async {
      final first = await loader().load();
      final second = await loader().load();

      expect(first.deviceId, 'device-1');
      expect(second.deviceId, 'device-1');
      expect(preferences.values[ClientInfoLoader.deviceIdKey], 'device-1');
    });

    test('is replaced when the saved value is unusable', () async {
      preferences.values[ClientInfoLoader.deviceIdKey] = 'x' * 200;

      final info = await loader().load();

      expect(info.deviceId, 'device-1');
    });

    test('is still provided when storage fails', () async {
      preferences.failWith = PlatformException(code: 'broken');

      final info = await loader().load();

      expect(info.deviceId, 'device-1');
    });
  });

  group('app version', () {
    test('combines the version and build number', () async {
      final info = await loader().load();

      expect(info.appVersion, '1.4.0+7');
    });

    test('omits an empty build number', () async {
      final info = await loader(
        packageInfo: () async => _packageInfo(buildNumber: ''),
      ).load();

      expect(info.appVersion, '1.4.0');
    });

    test('is cut to the length the backend stores', () async {
      final info = await loader(
        packageInfo: () async => _packageInfo(version: '1.0.0-${'a' * 40}'),
      ).load();

      expect(info.appVersion.length, ClientInfoLoader.maxAppVersionLength);
    });

    test('falls back to "unknown" when it cannot be read', () async {
      final info = await loader(
        packageInfo: () => Future.error(PlatformException(code: 'broken')),
      ).load();

      expect(info.appVersion, 'unknown');
    });
  });

  group('device description', () {
    test('names the model and system for the device list', () async {
      final info = await loader().load();

      expect(info.deviceModel, 'Google Pixel 8');
      expect(info.osVersion, 'Android 15');
    });

    test('is left out when the device cannot be read', () async {
      final info = await loader(
        describeDevice: (_) => Future.error(PlatformException(code: 'broken')),
      ).load();

      expect(info.deviceModel, isNull);
      expect(info.osVersion, isNull);
      expect(info.deviceId, 'device-1');
    });

    test('is cut to the length the backend stores', () async {
      final info = await loader(
        describeDevice: (_) async =>
            DeviceDescription(model: 'M' * 100, osVersion: '  '),
      ).load();

      expect(info.deviceModel, 'M' * ClientInfoLoader.maxDeviceModelLength);
      expect(info.osVersion, isNull);
    });

    test('names Android phones the way people know them', () {
      expect(androidModelName('Google', 'Pixel 8'), 'Google Pixel 8');
      expect(androidModelName('samsung', 'SM-S918B'), 'Samsung SM-S918B');
      expect(androidModelName('OnePlus', 'OnePlus 12'), 'OnePlus 12');
      expect(androidModelName('', 'Phone'), 'Phone');
    });
  });

  test('reports the platforms the backend distinguishes', () async {
    expect((await loader().load()).platform, ClientPlatform.android);
    expect(
      (await loader(platform: TargetPlatform.iOS).load()).platform,
      ClientPlatform.ios,
    );
    expect(
      (await loader(platform: TargetPlatform.windows).load()).platform,
      isNull,
    );
  });
}
