import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_error_code.dart';
import 'api_exception.dart';

/// Maximum automatic retries for a provider that failed with a transient error.
const apiMaxRetries = 3;

/// Decides whether Riverpod retries a provider that threw.
///
/// Riverpod retries every failed provider by default. That only helps with
/// failures that can succeed on a second attempt: a dropped connection, a
/// timeout, a brief server outage. Validation errors, missing resources and
/// quota limits would fail the same way again, so they aren't retried.
Duration? apiRetryPolicy(int retryCount, Object error) {
  if (!_isTransient(error)) return null;
  return ProviderContainer.defaultRetry(
    retryCount,
    error,
    maxRetries: apiMaxRetries,
  );
}

bool _isTransient(Object error) {
  return switch (error) {
    NetworkException(
      failure: NetworkFailure.offline || NetworkFailure.timeout,
    ) =>
      true,
    ApiErrorException(code: ApiErrorCode.serviceUnavailable) => true,
    UnexpectedResponseException(statusCode: 502 || 503 || 504) => true,
    _ => false,
  };
}
