import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/auth/auth_interceptor.dart';
import 'package:kinvo/src/core/auth/auth_tokens.dart';
import 'package:kinvo/src/core/auth/session_manager.dart';
import 'package:kinvo/src/core/auth/session_status.dart';
import 'package:kinvo/src/core/network/api_client.dart';
import 'package:kinvo/src/core/network/api_dio.dart';
import 'package:kinvo/src/core/network/api_envelope.dart';
import 'package:kinvo/src/core/network/api_error_code.dart';
import 'package:kinvo/src/core/network/api_exception.dart';

import '../../helpers/auth_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';

/// A fake backend whose `/users/me` accepts exactly one access token.
final class FakeBackend {
  String acceptedAccessToken = 'access-2';

  /// How `/users/me` answers any other token.
  int rejectionStatus = 401;
  String rejectionCode = 'AUTH_TOKEN_EXPIRED';

  /// Answers `/auth/refresh`. Defaults to issuing pair "2" after a short
  /// delay, so concurrent requests overlap.
  Future<ResponseBody> Function() refresh = () async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return jsonResponse(200, tokenPairEnvelope('2'));
  };

  Future<ResponseBody> respond(RequestOptions options) async {
    if (options.uri.path.endsWith('/auth/refresh')) return refresh();

    final token = sentBearerToken(options);
    if (token == null) {
      return jsonResponse(
        401,
        errorEnvelope('AUTH_REQUIRED', 'Please sign in.'),
      );
    }
    if (token != acceptedAccessToken) {
      return jsonResponse(
        rejectionStatus,
        errorEnvelope(rejectionCode, 'Rejected.'),
      );
    }
    return jsonResponse(200, successEnvelope({'ok': true}));
  }
}

void main() {
  final now = DateTime.utc(2026, 9, 15, 12);
  final validForHalfAnHour = testTokens(
    '1',
    expiresAt: now.add(const Duration(minutes: 30)),
  );

  late FakeBackend backend;
  late SessionHarness harness;
  late SessionManager session;
  late ApiClient api;

  Future<void> start({AuthTokens? saved}) async {
    backend = FakeBackend();
    harness = SessionHarness(
      respond: (options) => backend.respond(options),
      now: now,
    );
    if (saved != null) await harness.saveSession(saved);
    session = harness.createManager();

    final apiDio = createApiDio(testConfig)
      ..httpClientAdapter = harness.adapter;
    apiDio.interceptors.add(
      AuthInterceptor(session: session, retryClient: apiDio),
    );
    addTearDown(apiDio.close);
    api = ApiClient(apiDio);
  }

  Future<JsonMap> getProfile() => api.get('/users/me', decode: (json) => json);

  Iterable<String?> sentTokens() {
    return harness.requestsTo('/users/me').map(sentBearerToken);
  }

  Matcher throwsApiError(ApiErrorCode code) {
    return throwsA(
      isA<ApiErrorException>().having((e) => e.code, 'code', code),
    );
  }

  test('sends the session access token', () async {
    await start(saved: validForHalfAnHour);
    backend.acceptedAccessToken = 'access-1';

    await getProfile();

    expect(sentTokens(), ['access-1']);
  });

  test('sends no token when signed out', () async {
    await start();

    await expectLater(getProfile(), throwsApiError(ApiErrorCode.authRequired));

    expect(sentTokens(), [null]);
    expect(session.status.value, const SignedOut(SignOutReason.signedOut));
  });

  test('refreshes before sending a token that is about to expire', () async {
    await start(
      saved: testTokens('1', expiresAt: now.add(const Duration(seconds: 20))),
    );

    await getProfile();

    expect(harness.requestsTo('/auth/refresh'), hasLength(1));
    expect(sentTokens(), ['access-2']);
  });

  test(
    'retries once with a refreshed token after AUTH_TOKEN_EXPIRED',
    () async {
      await start(saved: validForHalfAnHour);

      final profile = await getProfile();

      expect(profile, {'ok': true});
      expect(harness.requestsTo('/auth/refresh'), hasLength(1));
      expect(sentTokens(), ['access-1', 'access-2']);
      expect((await harness.store.read())?.accessToken, 'access-2');
    },
  );

  test('concurrent expired requests share a single refresh', () async {
    await start(saved: validForHalfAnHour);

    final profiles = await Future.wait(List.generate(5, (_) => getProfile()));

    expect(profiles, everyElement({'ok': true}));
    expect(harness.requestsTo('/auth/refresh'), hasLength(1));
    expect(sentTokens().where((token) => token == 'access-2'), hasLength(5));
  });

  test(
    'does not retry again when the refreshed token is also refused',
    () async {
      await start(saved: validForHalfAnHour);
      backend.acceptedAccessToken = 'nothing-is-accepted';

      await expectLater(
        getProfile(),
        throwsApiError(ApiErrorCode.authTokenExpired),
      );

      expect(harness.requestsTo('/auth/refresh'), hasLength(1));
      expect(sentTokens(), ['access-1', 'access-2']);
      expect(session.status.value, const SignedIn());
    },
  );

  test('ends the session when the refresh token is no longer valid', () async {
    await start(saved: validForHalfAnHour);
    backend.refresh = () async => jsonResponse(
      401,
      errorEnvelope('AUTH_TOKEN_INVALID', 'Your session is no longer valid.'),
    );

    await expectLater(
      getProfile(),
      throwsApiError(ApiErrorCode.authTokenExpired),
    );

    expect(session.status.value, const SignedOut(SignOutReason.sessionEnded));
    expect(await harness.store.read(), isNull);
  });

  test(
    'reports being offline instead of signing out when refresh fails',
    () async {
      await start(saved: validForHalfAnHour);
      backend.refresh = () => throw const SocketException('offline');

      await expectLater(
        getProfile(),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.failure,
            'failure',
            NetworkFailure.offline,
          ),
        ),
      );

      expect(session.status.value, const SignedIn());
      expect(await harness.store.read(), validForHalfAnHour);
    },
  );

  test('ends the session when the access token is invalid', () async {
    await start(saved: validForHalfAnHour);
    backend.rejectionCode = 'AUTH_TOKEN_INVALID';

    await expectLater(
      getProfile(),
      throwsApiError(ApiErrorCode.authTokenInvalid),
    );

    expect(session.status.value, const SignedOut(SignOutReason.sessionEnded));
    expect(harness.requestsTo('/auth/refresh'), isEmpty);
  });

  test('keeps the session when the server says no token arrived', () async {
    // A proxy stripping the header must not sign every user out.
    await start(saved: validForHalfAnHour);
    backend.rejectionCode = 'AUTH_REQUIRED';

    await expectLater(getProfile(), throwsApiError(ApiErrorCode.authRequired));

    expect(session.status.value, const SignedIn());
  });

  test('marks the account suspended', () async {
    await start(saved: validForHalfAnHour);
    backend
      ..rejectionStatus = 403
      ..rejectionCode = 'ACCOUNT_SUSPENDED';

    await expectLater(
      getProfile(),
      throwsApiError(ApiErrorCode.accountSuspended),
    );

    expect(session.status.value, const AccountSuspended('Rejected.'));
    expect(harness.requestsTo('/auth/refresh'), isEmpty);
  });

  test('other failures pass through untouched', () async {
    await start(saved: validForHalfAnHour);
    backend
      ..rejectionStatus = 404
      ..rejectionCode = 'NOT_FOUND';

    await expectLater(getProfile(), throwsApiError(ApiErrorCode.notFound));

    expect(session.status.value, const SignedIn());
    expect(harness.requestsTo('/auth/refresh'), isEmpty);
  });
}
