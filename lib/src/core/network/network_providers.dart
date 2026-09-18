import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../device/device_providers.dart';
import 'api_client.dart';
import 'api_dio.dart';
import 'client_headers_interceptor.dart';

/// Build-time configuration. Override it in tests.
final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

/// Replaces the HTTP transport behind every API client. `null` in the app;
/// tests supply a fake server here so the real client wiring is exercised.
final httpClientAdapterProvider = Provider<HttpClientAdapter?>((ref) => null);

/// Dio for calls made without a session, including token refresh.
///
/// Never add the auth interceptor here: refreshing through it would recurse.
final publicApiDioProvider = Provider<Dio>((ref) {
  final dio = createApiDio(
    ref.watch(appConfigProvider),
    interceptors: [
      ClientHeadersInterceptor(() => ref.read(clientInfoProvider.future)),
    ],
  );
  if (ref.watch(httpClientAdapterProvider) case final adapter?) {
    dio.httpClientAdapter = adapter;
  }
  ref.onDispose(dio.close);
  return dio;
});

/// API client for endpoints that don't use the session, such as sign-in and
/// token refresh. Everything else uses `apiClientProvider`.
final publicApiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(publicApiDioProvider)),
);
