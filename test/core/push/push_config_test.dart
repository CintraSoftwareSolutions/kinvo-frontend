import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/config/app_config.dart';
import 'package:kinvo/src/core/push/push_config.dart';

Map<String, String> _settings({
  bool android = true,
  bool ios = true,
  Map<String, String> changes = const {},
}) {
  return {
    PushConfig.projectIdKey: 'kinvo-staging',
    PushConfig.messagingSenderIdKey: '1234567890',
    if (android) ...{
      PushConfig.androidApiKeyKey: 'android-api-key',
      PushConfig.androidAppIdKey: '1:1234567890:android:abc',
    },
    if (ios) ...{
      PushConfig.iosApiKeyKey: 'ios-api-key',
      PushConfig.iosAppIdKey: '1:1234567890:ios:def',
      PushConfig.iosBundleIdKey: 'app.kinvo',
    },
    ...changes,
  };
}

void main() {
  test('a build without Firebase settings has push notifications off', () {
    expect(PushConfig.parse(const {}), isNull);
    expect(PushConfig.parse(const {PushConfig.projectIdKey: '  '}), isNull);
  });

  test('gives each platform its own app', () {
    final config = PushConfig.parse(_settings())!;

    final android = config.optionsFor(TargetPlatform.android)!;
    expect(android.projectId, 'kinvo-staging');
    expect(android.messagingSenderId, '1234567890');
    expect(android.apiKey, 'android-api-key');
    expect(android.appId, '1:1234567890:android:abc');

    final ios = config.optionsFor(TargetPlatform.iOS)!;
    expect(ios.apiKey, 'ios-api-key');
    expect(ios.iosBundleId, 'app.kinvo');

    expect(config.optionsFor(TargetPlatform.windows), isNull);
  });

  test('a platform without an app gets no options', () {
    final config = PushConfig.parse(_settings(ios: false))!;

    expect(config.optionsFor(TargetPlatform.android), isNotNull);
    expect(config.optionsFor(TargetPlatform.iOS), isNull);
  });

  test('refuses half a configuration, rather than quietly never receiving '
      'a notification', () {
    expect(
      () => PushConfig.parse(
        _settings(changes: const {PushConfig.messagingSenderIdKey: ''}),
      ),
      throwsA(isA<AppConfigException>()),
    );
    expect(
      () => PushConfig.parse(
        _settings(changes: const {PushConfig.iosBundleIdKey: ''}),
      ),
      throwsA(isA<AppConfigException>()),
    );
    expect(
      () => PushConfig.parse(_settings(android: false, ios: false)),
      throwsA(isA<AppConfigException>()),
    );
  });
}
