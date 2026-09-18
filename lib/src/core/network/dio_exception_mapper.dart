import 'dart:io';

import 'package:dio/dio.dart';

import 'api_envelope.dart';
import 'api_exception.dart';
import 'api_headers.dart';

/// Converts a failed Dio request into the [ApiException] the app handles.
ApiException mapDioException(DioException error) {
  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.transformTimeout => const NetworkException(
      NetworkFailure.timeout,
    ),
    DioExceptionType.connectionError => const NetworkException(
      NetworkFailure.offline,
    ),
    DioExceptionType.badCertificate => const NetworkException(
      NetworkFailure.insecureConnection,
    ),
    DioExceptionType.cancel => const RequestCancelledException(),
    DioExceptionType.badResponse => _fromErrorResponse(error),
    DioExceptionType.unknown => _fromUnknownFailure(error),
  };
}

ApiException _fromErrorResponse(DioException error) {
  final response = error.response;
  final statusCode = response?.statusCode;
  if (response == null || statusCode == null) {
    return UnexpectedResponseException(
      reason: 'An error response arrived without a status code.',
      cause: error,
    );
  }

  final requestId = response.headers.value(ApiHeaders.requestId);
  final body = ApiEnvelope.tryReadError(response.data);
  if (body == null) {
    // Typically a CDN or proxy error page, which never uses the envelope.
    return UnexpectedResponseException(
      reason: 'HTTP $statusCode response without an error envelope.',
      statusCode: statusCode,
      requestId: requestId,
    );
  }

  return ApiErrorException(
    code: body.code,
    message: body.message,
    statusCode: statusCode,
    details: body.details,
    requestId: requestId,
    retryAfter: _retryAfter(response.headers, body.details),
  );
}

/// Dio's IO adapter already classifies socket failures, but anything thrown
/// outside it (a custom adapter, an interceptor) arrives as `unknown`.
ApiException _fromUnknownFailure(DioException error) {
  return switch (error.error) {
    // An interceptor already decided what went wrong, for example that a
    // token couldn't be refreshed while offline.
    final ApiException decided => decided,
    SocketException() => const NetworkException(NetworkFailure.offline),
    TlsException() => const NetworkException(NetworkFailure.insecureConnection),
    _ => UnexpectedResponseException(
      reason: 'The request failed before a response was read.',
      statusCode: error.response?.statusCode,
      requestId: error.response?.headers.value(ApiHeaders.requestId),
      cause: error.error ?? error,
    ),
  };
}

/// Reads `Retry-After` as whole seconds, falling back to the
/// `retry_after_seconds` detail the backend's rate limiter adds.
Duration? _retryAfter(Headers headers, JsonMap? details) {
  final seconds =
      int.tryParse(headers.value(ApiHeaders.retryAfter) ?? '') ??
      switch (details?['retry_after_seconds']) {
        final int value => value,
        _ => null,
      };
  return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
}
