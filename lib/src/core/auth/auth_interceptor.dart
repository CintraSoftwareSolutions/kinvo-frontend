import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../network/api_error_code.dart';
import '../network/api_exception.dart';
import '../network/api_headers.dart';
import '../network/dio_exception_mapper.dart';
import 'session_manager.dart';

/// Sends the session's access token with API requests and recovers from
/// routine token expiry.
///
/// Tokens are refreshed shortly before they expire. If the server still
/// answers `AUTH_TOKEN_EXPIRED` (the device clock is wrong, or the token lapsed
/// in flight), the request is retried once with a refreshed token. Concurrent
/// requests share a single refresh.
///
/// `AUTH_TOKEN_INVALID` ends the session and `ACCOUNT_SUSPENDED` marks the
/// account suspended. Every other failure passes through unchanged.
final class AuthInterceptor extends Interceptor {
  /// [retryClient] must be the Dio instance this interceptor is added to, so
  /// retried requests get the same headers and logging.
  AuthInterceptor({required SessionManager session, required Dio retryClient})
    : _session = session,
      _retryClient = retryClient;

  static const _retriedKey = 'kinvo.auth.retried';
  static const _bearerPrefix = 'Bearer ';

  final SessionManager _session;
  final Dio _retryClient;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _session.accessTokenForRequest();
      if (token == null) {
        options.headers.remove(ApiHeaders.authorization);
      } else {
        options.headers[ApiHeaders.authorization] = '$_bearerPrefix$token';
      }
      handler.next(options);
    } on Object catch (error, stackTrace) {
      // Typically the token couldn't be refreshed (offline, rate limited).
      // Report that rather than send a request that would be refused; the
      // error mapper passes an ApiException through unchanged.
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      await _handleError(err, handler);
    } on Object catch (error, stackTrace) {
      // A bug here must fail the request, never leave it hanging.
      developer.log(
        'Auth error handling failed.',
        name: 'kinvo.auth',
        error: error,
        stackTrace: stackTrace,
      );
      handler.next(err);
    }
  }

  Future<void> _handleError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final sentToken = _sentAccessToken(err.requestOptions);
    if (sentToken == null) {
      handler.next(err);
      return;
    }

    switch (mapDioException(err)) {
      case ApiErrorException(code: ApiErrorCode.authTokenExpired)
          when _canRetry(err.requestOptions):
        await _retryWithFreshToken(err, sentToken, handler);
      case ApiErrorException(code: ApiErrorCode.authTokenInvalid):
        await _session.handleRejectedSession(sentToken);
        handler.next(err);
      case ApiErrorException(
        code: ApiErrorCode.accountSuspended,
        :final message,
      ):
        _session.handleAccountSuspended(message);
        handler.next(err);
      case _:
        handler.next(err);
    }
  }

  Future<void> _retryWithFreshToken(
    DioException err,
    String rejectedToken,
    ErrorInterceptorHandler handler,
  ) async {
    final String? token;
    try {
      token = await _session.accessTokenAfterExpiry(rejectedToken);
    } on ApiException catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: error,
          stackTrace: stackTrace,
        ),
      );
      return;
    }

    if (token == null) {
      // The session ended; the original expiry error is the honest answer.
      handler.next(err);
      return;
    }

    final retry = err.requestOptions.copyWith(
      headers: {
        ...err.requestOptions.headers,
        ApiHeaders.authorization: '$_bearerPrefix$token',
      },
      extra: {...err.requestOptions.extra, _retriedKey: true},
    );

    try {
      handler.resolve(await _retryClient.fetch<Object?>(retry));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Retries happen once, and only for bodies that can be sent twice.
  static bool _canRetry(RequestOptions options) {
    final data = options.data;
    return options.extra[_retriedKey] != true &&
        data is! FormData &&
        data is! Stream<Object?>;
  }

  static String? _sentAccessToken(RequestOptions options) {
    final header = options.headers[ApiHeaders.authorization];
    return header is String && header.startsWith(_bearerPrefix)
        ? header.substring(_bearerPrefix.length)
        : null;
  }
}
