import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import 'api_headers.dart';

/// Logs one line per API call: method, path, status, duration and the
/// server's request id.
///
/// Headers, query strings and bodies are never logged: they carry access
/// tokens and personal data. Add this interceptor in debug builds only.
final class ApiLoggingInterceptor extends Interceptor {
  static const _stopwatchKey = 'kinvo.api.stopwatch';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_stopwatchKey] = Stopwatch()..start();
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _log(
      response.requestOptions,
      outcome: '${response.statusCode}',
      response: response,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    _log(
      err.requestOptions,
      outcome: response?.statusCode?.toString() ?? err.type.name,
      response: response,
    );
    handler.next(err);
  }

  void _log(
    RequestOptions options, {
    required String outcome,
    Response<dynamic>? response,
  }) {
    final stopwatch = options.extra[_stopwatchKey];
    final elapsed = stopwatch is Stopwatch
        ? ' ${stopwatch.elapsedMilliseconds}ms'
        : '';
    final requestId = response?.headers.value(ApiHeaders.requestId);
    developer.log(
      '${options.method} ${options.uri.path} → $outcome$elapsed'
      '${requestId == null ? '' : ' [$requestId]'}',
      name: 'kinvo.api',
    );
  }
}
