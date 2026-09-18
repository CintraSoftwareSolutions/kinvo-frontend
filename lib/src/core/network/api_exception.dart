import 'package:flutter/foundation.dart';

import 'api_error_code.dart';

/// A failed API call.
///
/// The subtypes are exhaustive, so a `switch` over an [ApiException] handles
/// every kind of failure the network layer can report.
@immutable
sealed class ApiException implements Exception {
  const ApiException();

  /// Text that can be shown to the user as-is.
  String get message;
}

/// The server rejected the request and explained why in its error envelope.
final class ApiErrorException extends ApiException {
  const ApiErrorException({
    required this.code,
    required this.message,
    required this.statusCode,
    this.details,
    this.requestId,
    this.retryAfter,
  });

  /// Key under [fieldErrors] for problems that don't belong to a single field.
  static const formErrorsKey = '_';

  final ApiErrorCode code;

  @override
  final String message;

  final int statusCode;

  /// Extra context whose shape depends on [code], such as field errors for
  /// [ApiErrorCode.validationFailed] or limits for [ApiErrorCode.quotaExceeded].
  final Map<String, Object?>? details;

  /// The server's `X-Request-Id`, for matching a report with server logs.
  final String? requestId;

  /// How long to wait before trying again, when the server said so.
  final Duration? retryAfter;

  /// Messages for each invalid field of a [ApiErrorCode.validationFailed]
  /// response, keyed by field path (for example `date_of_birth`).
  ///
  /// Empty for every other code.
  Map<String, List<String>> get fieldErrors {
    final details = this.details;
    if (code != ApiErrorCode.validationFailed || details == null) {
      return const {};
    }
    return {
      for (final MapEntry(:key, :value) in details.entries)
        if (value is List<Object?>) key: value.whereType<String>().toList(),
    };
  }

  @override
  String toString() =>
      'ApiErrorException(${code.wireValue}, status: $statusCode, '
      'requestId: $requestId)';
}

/// Why a request never got an answer from the server.
enum NetworkFailure {
  /// There is no usable connection.
  offline,

  /// The connection or the server was too slow.
  timeout,

  /// A secure connection couldn't be established, for example behind a
  /// captive portal on public Wi-Fi.
  insecureConnection,
}

/// The request never reached the server, or the server didn't answer in time.
final class NetworkException extends ApiException {
  const NetworkException(this.failure);

  final NetworkFailure failure;

  @override
  String get message => switch (failure) {
    NetworkFailure.offline =>
      "Can't connect right now. Check your internet connection and try again.",
    NetworkFailure.timeout =>
      'The server took too long to respond. Please try again.',
    NetworkFailure.insecureConnection =>
      "Can't connect securely. If you're on public Wi-Fi, try another network.",
  };

  @override
  String toString() => 'NetworkException(${failure.name})';
}

/// The server answered with something this app can't interpret, such as a
/// CDN error page or a body that doesn't match the API contract.
final class UnexpectedResponseException extends ApiException {
  const UnexpectedResponseException({
    required this.reason,
    this.statusCode,
    this.requestId,
    this.cause,
  });

  /// What didn't match, for developers. Never shown to users.
  final String reason;

  final int? statusCode;

  final String? requestId;

  /// The underlying error, when there was one.
  final Object? cause;

  @override
  String get message => 'Something went wrong. Please try again.';

  @override
  String toString() =>
      'UnexpectedResponseException($reason, status: $statusCode, '
      'requestId: $requestId, cause: $cause)';
}

/// The caller cancelled the request before it finished.
final class RequestCancelledException extends ApiException {
  const RequestCancelledException();

  @override
  String get message => 'The request was cancelled.';

  @override
  String toString() => 'RequestCancelledException()';
}
