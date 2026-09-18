import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_interceptor.dart';
import '../auth/auth_providers.dart';
import '../device/device_providers.dart';
import 'api_client.dart';
import 'api_dio.dart';
import 'client_headers_interceptor.dart';
import 'network_providers.dart';

/// Dio for the session's API calls: identifies the device and sends the
/// access token, refreshing it when needed.
final apiDioProvider = Provider<Dio>((ref) {
  final dio = createApiDio(
    ref.watch(appConfigProvider),
    interceptors: [
      ClientHeadersInterceptor(() => ref.read(clientInfoProvider.future)),
    ],
  );
  dio.interceptors.add(
    AuthInterceptor(
      session: ref.watch(sessionManagerProvider),
      retryClient: dio,
    ),
  );
  if (ref.watch(httpClientAdapterProvider) case final adapter?) {
    dio.httpClientAdapter = adapter;
  }
  ref.onDispose(dio.close);
  return dio;
});

/// Entry point for every repository that talks to the backend.
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(apiDioProvider)),
);
