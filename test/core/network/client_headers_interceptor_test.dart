import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/device/client_info.dart';
import 'package:kinvo/src/core/network/api_dio.dart';
import 'package:kinvo/src/core/network/client_headers_interceptor.dart';

import '../../helpers/auth_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter adapter;

  Dio dioWith(ClientInfo info) {
    adapter = FakeHttpAdapter(
      (_) async => jsonResponse(200, successEnvelope(<String, Object?>{})),
    );
    final dio = createApiDio(
      testConfig,
      interceptors: [
        ClientHeadersInterceptor(() async => info, languageTag: () => 'en-GB'),
      ],
    )..httpClientAdapter = adapter;
    addTearDown(dio.close);
    return dio;
  }

  test('identifies the device, platform, version and language', () async {
    final dio = dioWith(
      const ClientInfo(
        deviceId: 'device-1',
        platform: ClientPlatform.ios,
        appVersion: '1.0.0+1',
      ),
    );

    await dio.get<Object?>('/config');

    final headers = adapter.requests.single.headers;
    expect(headers['x-device-id'], 'device-1');
    expect(headers['x-platform'], 'ios');
    expect(headers['x-app-version'], '1.0.0+1');
    expect(headers['accept-language'], 'en-GB');
  });

  test('names the device for the device list when it is known', () async {
    final dio = dioWith(
      const ClientInfo(
        deviceId: 'device-1',
        platform: ClientPlatform.android,
        appVersion: '1.0.0',
        deviceModel: 'Google Pixel 8',
        osVersion: 'Android 15',
      ),
    );

    await dio.get<Object?>('/config');

    final headers = adapter.requests.single.headers;
    expect(headers['x-device-model'], 'Google Pixel 8');
    expect(headers['x-os-version'], 'Android 15');
  });

  test('leaves the device description out when it is not known', () async {
    final dio = dioWith(
      const ClientInfo(
        deviceId: 'device-1',
        platform: ClientPlatform.android,
        appVersion: '1.0.0',
      ),
    );

    await dio.get<Object?>('/config');

    final headers = adapter.requests.single.headers;
    expect(headers.containsKey('x-device-model'), isFalse);
    expect(headers.containsKey('x-os-version'), isFalse);
  });

  test(
    'leaves out the platform when the backend has no value for it',
    () async {
      final dio = dioWith(
        const ClientInfo(
          deviceId: 'device-1',
          platform: null,
          appVersion: '1.0.0',
        ),
      );

      await dio.get<Object?>('/config');

      expect(
        adapter.requests.single.headers.containsKey('x-platform'),
        isFalse,
      );
    },
  );

  test('keeps a language chosen for a specific request', () async {
    final dio = dioWith(
      const ClientInfo(
        deviceId: 'device-1',
        platform: ClientPlatform.android,
        appVersion: '1.0.0',
      ),
    );

    await dio.get<Object?>(
      '/config',
      options: Options(headers: {'accept-language': 'ur'}),
    );

    expect(adapter.requests.single.headers['accept-language'], 'ur');
  });
}
