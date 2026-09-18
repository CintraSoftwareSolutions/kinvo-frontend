import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/config/app_config.dart';
import 'package:kinvo/src/core/network/api_client.dart';
import 'package:kinvo/src/core/network/api_dio.dart';
import 'package:kinvo/src/core/network/api_error_code.dart';
import 'package:kinvo/src/core/network/api_exception.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter adapter;

  ApiClient clientRespondingWith(FakeResponder respond) {
    adapter = FakeHttpAdapter(respond);
    final dio = createApiDio(
      AppConfig(apiBaseUrl: Uri.parse('https://api.test/api/v1')),
    )..httpClientAdapter = adapter;
    addTearDown(dio.close);
    return ApiClient(dio);
  }

  Future<ResponseBody> Function(RequestOptions) answer(ResponseBody body) {
    return (_) async => body;
  }

  Matcher throwsApiError(ApiErrorCode code) {
    return throwsA(
      isA<ApiErrorException>().having((e) => e.code, 'code', code),
    );
  }

  group('get', () {
    test(
      'decodes the data object and joins the path to the base URL',
      () async {
        final client = clientRespondingWith(
          answer(jsonResponse(200, successEnvelope({'display_name': 'Sarah'}))),
        );

        final name = await client.get(
          '/users/me',
          decode: (json) => json['display_name']! as String,
        );

        expect(name, 'Sarah');
        final request = adapter.requests.single;
        expect(request.method, 'GET');
        expect(request.uri.toString(), 'https://api.test/api/v1/users/me');
      },
    );

    test('leaves out query parameters whose value is null', () async {
      final client = clientRespondingWith(
        answer(jsonResponse(200, successEnvelope(<String, Object?>{}))),
      );

      await client.get(
        '/matches',
        query: {'archived': true, 'mode': null},
        decode: ApiClient.ignoreData,
      );

      expect(adapter.requests.single.uri.queryParameters, {'archived': 'true'});
    });
  });

  group('getPage', () {
    test('decodes items and pagination and sends the cursor', () async {
      final client = clientRespondingWith(
        answer(
          jsonResponse(
            200,
            successEnvelope(
              [
                {'id': 'a'},
                {'id': 'b'},
              ],
              meta: {
                'pagination': {
                  'next_cursor': 'next-page',
                  'has_more': true,
                  'limit': 2,
                },
              },
            ),
          ),
        ),
      );

      final page = await client.getPage(
        '/matches',
        cursor: 'this-page',
        limit: 2,
        decodeItem: (json) => json['id']! as String,
      );

      expect(page.items, ['a', 'b']);
      expect(page.nextCursor, 'next-page');
      expect(page.hasMore, isTrue);
      expect(page.limit, 2);
      expect(adapter.requests.single.uri.queryParameters, {
        'cursor': 'this-page',
        'limit': '2',
      });
    });

    test('accepts the last page, whose cursor is null', () async {
      final client = clientRespondingWith(
        answer(
          jsonResponse(
            200,
            successEnvelope(
              <Object?>[],
              meta: {
                'pagination': {
                  'next_cursor': null,
                  'has_more': false,
                  'limit': 20,
                },
              },
            ),
          ),
        ),
      );

      final page = await client.getPage(
        '/notifications',
        decodeItem: (json) => json,
      );

      expect(page.items, isEmpty);
      expect(page.nextCursor, isNull);
      expect(page.hasMore, isFalse);
      expect(adapter.requests.single.uri.queryParameters, isEmpty);
    });

    test('rejects list items that are not objects', () async {
      final client = clientRespondingWith(
        answer(
          jsonResponse(
            200,
            successEnvelope(
              [1, 2],
              meta: {
                'pagination': {
                  'next_cursor': null,
                  'has_more': false,
                  'limit': 20,
                },
              },
            ),
          ),
        ),
      );

      await expectLater(
        client.getPage('/matches', decodeItem: (json) => json),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });
  });

  group('requests with a body', () {
    test('sends the body as JSON with the given method', () async {
      final client = clientRespondingWith(
        answer(jsonResponse(201, successEnvelope({'id': 'plan-1'}))),
      );
      final body = {'match_id': 'match-1', 'propose': false};

      final id = await client.post(
        '/plans',
        body: body,
        decode: (json) => json['id']! as String,
      );

      expect(id, 'plan-1');
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.data, body);
      expect(request.contentType, Headers.jsonContentType);
    });
  });

  group('error envelopes', () {
    test(
      'become ApiErrorException with status, message and request id',
      () async {
        final client = clientRespondingWith(
          answer(
            jsonResponse(
              404,
              errorEnvelope(
                'NOT_FOUND',
                'We could not find what you were looking for.',
              ),
              headers: {
                'x-request-id': ['req-123'],
              },
            ),
          ),
        );

        await expectLater(
          client.get('/users/someone', decode: ApiClient.ignoreData),
          throwsA(
            isA<ApiErrorException>()
                .having((e) => e.code, 'code', ApiErrorCode.notFound)
                .having((e) => e.statusCode, 'statusCode', 404)
                .having(
                  (e) => e.message,
                  'message',
                  'We could not find what you were looking for.',
                )
                .having((e) => e.requestId, 'requestId', 'req-123'),
          ),
        );
      },
    );

    test('expose validation messages per field', () async {
      final client = clientRespondingWith(
        answer(
          jsonResponse(
            400,
            errorEnvelope(
              'VALIDATION_FAILED',
              'Some fields need attention.',
              details: {
                'email': ['Enter a valid email address.'],
                '_': ['Choose a venue or enter a location.'],
              },
            ),
          ),
        ),
      );

      await expectLater(
        client.post('/auth/register', decode: ApiClient.ignoreData),
        throwsA(
          isA<ApiErrorException>().having((e) => e.fieldErrors, 'fieldErrors', {
            'email': ['Enter a valid email address.'],
            ApiErrorException.formErrorsKey: [
              'Choose a venue or enter a location.',
            ],
          }),
        ),
      );
    });

    test('keep paywall details for quota errors', () async {
      final details = {
        'quota': 'swipes',
        'limit': 50,
        'used': 50,
        'remaining': 0,
        'resets_at': '2026-09-16T00:00:00.000Z',
        'upgrade_available': true,
      };
      final client = clientRespondingWith(
        answer(
          jsonResponse(
            422,
            errorEnvelope(
              'QUOTA_EXCEEDED',
              "You've used all your likes for today.",
              details: details,
            ),
          ),
        ),
      );

      await expectLater(
        client.post('/discovery/dating/swipe', decode: ApiClient.ignoreData),
        throwsA(
          isA<ApiErrorException>()
              .having((e) => e.code, 'code', ApiErrorCode.quotaExceeded)
              .having((e) => e.details, 'details', details)
              .having((e) => e.fieldErrors, 'fieldErrors', isEmpty),
        ),
      );
    });

    test('map unrecognised codes to unknown but keep the message', () async {
      final client = clientRespondingWith(
        answer(
          jsonResponse(409, errorEnvelope('SOMETHING_NEW', 'A new rule.')),
        ),
      );

      await expectLater(
        client.get('/config', decode: ApiClient.ignoreData),
        throwsA(
          isA<ApiErrorException>()
              .having((e) => e.code, 'code', ApiErrorCode.unknown)
              .having((e) => e.message, 'message', 'A new rule.'),
        ),
      );
    });

    test('read the Retry-After header when rate limited', () async {
      final client = clientRespondingWith(
        answer(
          jsonResponse(
            429,
            errorEnvelope('RATE_LIMITED', 'Too many requests.'),
            headers: {
              'retry-after': ['30'],
            },
          ),
        ),
      );

      await expectLater(
        client.get('/matches', decode: ApiClient.ignoreData),
        throwsA(
          isA<ApiErrorException>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 30),
          ),
        ),
      );
    });

    test(
      'fall back to retry_after_seconds when the header is missing',
      () async {
        final client = clientRespondingWith(
          answer(
            jsonResponse(
              429,
              errorEnvelope(
                'RATE_LIMITED',
                'Too many requests.',
                details: {'retry_after_seconds': 12},
              ),
            ),
          ),
        );

        await expectLater(
          client.get('/matches', decode: ApiClient.ignoreData),
          throwsA(
            isA<ApiErrorException>().having(
              (e) => e.retryAfter,
              'retryAfter',
              const Duration(seconds: 12),
            ),
          ),
        );
      },
    );

    test('distinguish expired from invalid sessions', () async {
      final expired = clientRespondingWith(
        answer(
          jsonResponse(401, errorEnvelope('AUTH_TOKEN_EXPIRED', 'Expired.')),
        ),
      );
      await expectLater(
        expired.get('/auth/me', decode: ApiClient.ignoreData),
        throwsApiError(ApiErrorCode.authTokenExpired),
      );

      final invalid = clientRespondingWith(
        answer(
          jsonResponse(401, errorEnvelope('AUTH_TOKEN_INVALID', 'Invalid.')),
        ),
      );
      await expectLater(
        invalid.get('/auth/me', decode: ApiClient.ignoreData),
        throwsApiError(ApiErrorCode.authTokenInvalid),
      );
    });
  });

  group('unexpected responses', () {
    test('an error page without an envelope keeps its status code', () async {
      final client = clientRespondingWith(
        answer(textResponse(502, '<html>502 Bad Gateway</html>')),
      );

      await expectLater(
        client.get('/health', decode: ApiClient.ignoreData),
        throwsA(
          isA<UnexpectedResponseException>().having(
            (e) => e.statusCode,
            'statusCode',
            502,
          ),
        ),
      );
    });

    test('a success status without an envelope is rejected', () async {
      final client = clientRespondingWith(
        answer(jsonResponse(200, {'id': 'not-wrapped'})),
      );

      await expectLater(
        client.get('/users/me', decode: ApiClient.ignoreData),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });

    test(
      'a decoder that does not match the payload is reported, not thrown raw',
      () async {
        final client = clientRespondingWith(
          answer(jsonResponse(200, successEnvelope({'id': 42}))),
        );

        await expectLater(
          client.get('/users/me', decode: (json) => json['id']! as String),
          throwsA(
            isA<UnexpectedResponseException>()
                .having((e) => e.statusCode, 'statusCode', 200)
                .having((e) => e.cause, 'cause', isA<TypeError>()),
          ),
        );
      },
    );
  });

  group('transport failures', () {
    test('timeouts become NetworkFailure.timeout', () async {
      final client = clientRespondingWith(
        (options) => throw DioException.connectionTimeout(
          timeout: const Duration(seconds: 10),
          requestOptions: options,
        ),
      );

      await expectLater(
        client.get('/config', decode: ApiClient.ignoreData),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.failure,
            'failure',
            NetworkFailure.timeout,
          ),
        ),
      );
    });

    test('socket errors become NetworkFailure.offline', () async {
      final client = clientRespondingWith(
        (_) => throw const SocketException('Failed host lookup'),
      );

      await expectLater(
        client.get('/config', decode: ApiClient.ignoreData),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.failure,
            'failure',
            NetworkFailure.offline,
          ),
        ),
      );
    });

    test('TLS errors become NetworkFailure.insecureConnection', () async {
      final client = clientRespondingWith(
        (_) => throw const HandshakeException('Certificate rejected'),
      );

      await expectLater(
        client.get('/config', decode: ApiClient.ignoreData),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.failure,
            'failure',
            NetworkFailure.insecureConnection,
          ),
        ),
      );
    });

    test('a cancelled request becomes RequestCancelledException', () async {
      final client = clientRespondingWith(
        answer(jsonResponse(200, successEnvelope(<String, Object?>{}))),
      );
      final cancelToken = CancelToken()..cancel();

      await expectLater(
        client.get(
          '/config',
          decode: ApiClient.ignoreData,
          cancelToken: cancelToken,
        ),
        throwsA(isA<RequestCancelledException>()),
      );
    });
  });
}
