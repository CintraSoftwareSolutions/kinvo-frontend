import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'api_logging_interceptor.dart';

/// Builds a Dio instance for the Kinvo API.
///
/// [interceptors] run in order after request logging, so the log also records
/// requests an interceptor rejects or retries.
Dio createApiDio(
  AppConfig config, {
  Iterable<Interceptor> interceptors = const [],
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl.toString(),
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      headers: {Headers.acceptHeader: Headers.jsonContentType},
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(ApiLoggingInterceptor());
  }
  dio.interceptors.addAll(interceptors);

  return dio;
}
