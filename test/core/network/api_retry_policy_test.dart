import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/network/api_error_code.dart';
import 'package:kinvo/src/core/network/api_exception.dart';
import 'package:kinvo/src/core/network/api_retry_policy.dart';

ApiErrorException _apiError(ApiErrorCode code, int statusCode) {
  return ApiErrorException(
    code: code,
    message: 'message',
    statusCode: statusCode,
  );
}

void main() {
  group('apiRetryPolicy retries transient failures', () {
    final transient = <String, Object>{
      'offline': const NetworkException(NetworkFailure.offline),
      'timeout': const NetworkException(NetworkFailure.timeout),
      'service unavailable': _apiError(ApiErrorCode.serviceUnavailable, 503),
      'bad gateway page': const UnexpectedResponseException(
        reason: 'CDN error page',
        statusCode: 502,
      ),
      'gateway timeout page': const UnexpectedResponseException(
        reason: 'CDN error page',
        statusCode: 504,
      ),
    };

    for (final MapEntry(key: name, value: error) in transient.entries) {
      test(name, () {
        expect(apiRetryPolicy(0, error), isNotNull);
      });
    }

    test('with growing delays, up to $apiMaxRetries times', () {
      const error = NetworkException(NetworkFailure.timeout);
      final delays = [
        for (var attempt = 0; attempt <= apiMaxRetries; attempt++)
          apiRetryPolicy(attempt, error),
      ];

      expect(delays.take(apiMaxRetries), everyElement(isNotNull));
      expect(delays[0]! < delays[1]!, isTrue);
      expect(delays[1]! < delays[2]!, isTrue);
      expect(delays.last, isNull);
    });
  });

  group('apiRetryPolicy does not retry failures that would repeat', () {
    final permanent = <String, Object>{
      'insecure connection': const NetworkException(
        NetworkFailure.insecureConnection,
      ),
      'not found': _apiError(ApiErrorCode.notFound, 404),
      'quota exceeded': _apiError(ApiErrorCode.quotaExceeded, 422),
      'rate limited': _apiError(ApiErrorCode.rateLimited, 429),
      'internal error': _apiError(ApiErrorCode.internalError, 500),
      'session expired': _apiError(ApiErrorCode.authTokenExpired, 401),
      'contract mismatch': const UnexpectedResponseException(
        reason: 'decoder failed',
        statusCode: 200,
      ),
      'cancellation': const RequestCancelledException(),
      'programming error': StateError('bug'),
    };

    for (final MapEntry(key: name, value: error) in permanent.entries) {
      test(name, () {
        expect(apiRetryPolicy(0, error), isNull);
      });
    }
  });
}
