import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/auth/auth_providers.dart';
import 'package:kinvo/src/core/auth/auth_tokens.dart';
import 'package:kinvo/src/core/auth/session_manager.dart';
import 'package:kinvo/src/core/auth/session_status.dart';
import 'package:kinvo/src/core/network/api_exception.dart';

import '../../helpers/auth_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';

void main() {
  final now = DateTime.utc(2026, 9, 15, 12);
  final validTokens = testTokens(
    '1',
    expiresAt: now.add(const Duration(minutes: 30)),
  );

  late FakeResponder respond;
  late SessionHarness harness;

  setUp(() {
    respond = (options) async =>
        jsonResponse(404, errorEnvelope('NOT_FOUND', 'No.'));
    harness = SessionHarness(respond: (options) => respond(options), now: now);
  });

  Future<SessionManager> signedInManager([AuthTokens? tokens]) async {
    await harness.saveSession(tokens ?? validTokens);
    final manager = harness.createManager();
    await manager.ready;
    return manager;
  }

  group('restoring', () {
    test('starts signed out when nothing is saved', () async {
      final manager = harness.createManager();

      expect(manager.status.value, const SessionRestoring());
      await manager.ready;

      expect(manager.status.value, const SignedOut(SignOutReason.signedOut));
      expect(await manager.accessTokenForRequest(), isNull);
    });

    test('restores a saved session', () async {
      final manager = await signedInManager();

      expect(manager.status.value, const SignedIn());
      expect(await manager.accessTokenForRequest(), 'access-1');
    });
  });

  group('signing in and out', () {
    test('signIn saves the tokens', () async {
      final manager = harness.createManager();

      await manager.signIn(validTokens);

      expect(manager.status.value, const SignedIn());
      expect(await harness.store.read(), validTokens);
    });

    test('a session that is not remembered stays in memory', () async {
      final manager = harness.createManager();

      await manager.signIn(validTokens, remember: false);

      expect(manager.status.value, const SignedIn());
      expect(await manager.accessTokenForRequest(), 'access-1');
      expect(await harness.store.read(), isNull);
    });

    test(
      'refreshing a session that is not remembered does not save it',
      () async {
        final manager = harness.createManager();
        await manager.signIn(validTokens, remember: false);
        respond = (_) async => jsonResponse(200, tokenPairEnvelope('2'));

        await manager.refresh();

        expect(await manager.accessTokenForRequest(), 'access-2');
        expect(await harness.store.read(), isNull);
      },
    );

    test(
      'signOut forgets the session even when the server is unreachable',
      () async {
        final manager = await signedInManager();
        respond = (_) => throw const SocketException('offline');

        await manager.signOut();

        expect(manager.status.value, const SignedOut(SignOutReason.signedOut));
        expect(await harness.store.read(), isNull);
        expect(await manager.accessTokenForRequest(), isNull);
        expect(harness.requestsTo('/auth/logout').single.data, {
          'refresh_token': 'refresh-1',
        });
      },
    );
  });

  group('refresh', () {
    test('saves and returns the new pair', () async {
      final manager = await signedInManager();
      respond = (_) async => jsonResponse(200, tokenPairEnvelope('2'));

      final refreshed = await manager.refresh();

      expect(refreshed?.accessToken, 'access-2');
      expect(await harness.store.read(), refreshed);
      expect(harness.requestsTo('/auth/refresh').single.data, {
        'refresh_token': 'refresh-1',
      });
    });

    test('sends one request for concurrent callers', () async {
      final manager = await signedInManager();
      final response = Completer<ResponseBody>();
      respond = (_) => response.future;

      final pending = [manager.refresh(), manager.refresh(), manager.refresh()];
      response.complete(jsonResponse(200, tokenPairEnvelope('2')));
      final results = await Future.wait(pending);

      expect(
        results.map((tokens) => tokens?.accessToken),
        everyElement('access-2'),
      );
      expect(harness.requestsTo('/auth/refresh'), hasLength(1));
    });

    test('ends the session when the refresh token is rejected', () async {
      final manager = await signedInManager();
      respond = (_) async => jsonResponse(
        401,
        errorEnvelope('AUTH_TOKEN_INVALID', 'Your session is no longer valid.'),
      );

      expect(await manager.refresh(), isNull);
      expect(manager.status.value, const SignedOut(SignOutReason.sessionEnded));
      expect(await harness.store.read(), isNull);
    });

    test('keeps the session when refreshing fails temporarily', () async {
      final manager = await signedInManager();
      respond = (_) => throw const SocketException('offline');

      await expectLater(manager.refresh(), throwsA(isA<NetworkException>()));

      expect(manager.status.value, const SignedIn());
      expect(await harness.store.read(), validTokens);
    });

    test('keeps the session when rate limited', () async {
      final manager = await signedInManager();
      respond = (_) async => jsonResponse(
        429,
        errorEnvelope('RATE_LIMITED', 'Too many requests.'),
      );

      await expectLater(manager.refresh(), throwsA(isA<ApiErrorException>()));

      expect(manager.status.value, const SignedIn());
    });

    test(
      'discards and revokes a pair that arrives after signing out',
      () async {
        final manager = await signedInManager();
        final refreshResponse = Completer<ResponseBody>();
        respond = (options) {
          if (options.uri.path.endsWith('/auth/refresh')) {
            return refreshResponse.future;
          }
          return Future.value(
            jsonResponse(200, successEnvelope({'signed_out': true})),
          );
        };

        final refreshing = manager.refresh();
        await manager.signOut();
        refreshResponse.complete(jsonResponse(200, tokenPairEnvelope('2')));

        expect(await refreshing, isNull);
        await settle();
        expect(manager.status.value, const SignedOut(SignOutReason.signedOut));
        expect(await harness.store.read(), isNull);
        expect(
          harness.requestsTo('/auth/logout').map((r) => r.data),
          containsAll([
            {'refresh_token': 'refresh-1'},
            {'refresh_token': 'refresh-2'},
          ]),
        );
      },
    );
  });

  group('accessTokenForRequest', () {
    test('refreshes a token that is about to expire', () async {
      final manager = await signedInManager(
        testTokens('1', expiresAt: now.add(const Duration(seconds: 30))),
      );
      respond = (_) async => jsonResponse(200, tokenPairEnvelope('2'));

      expect(await manager.accessTokenForRequest(), 'access-2');
    });

    test(
      'uses a still-valid token when refreshing fails temporarily',
      () async {
        final manager = await signedInManager(
          testTokens('1', expiresAt: now.add(const Duration(seconds: 30))),
        );
        respond = (_) => throw const SocketException('offline');

        expect(await manager.accessTokenForRequest(), 'access-1');
      },
    );

    test('reports the failure when the token has already expired', () async {
      final manager = await signedInManager(
        testTokens('1', expiresAt: now.subtract(const Duration(seconds: 5))),
      );
      respond = (_) => throw const SocketException('offline');

      await expectLater(
        manager.accessTokenForRequest(),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('server rejections', () {
    test('an invalid session ends it', () async {
      final manager = await signedInManager();

      await manager.handleRejectedSession('access-1');

      expect(manager.status.value, const SignedOut(SignOutReason.sessionEnded));
      expect(await harness.store.read(), isNull);
    });

    test('a rejection of an already replaced token is ignored', () async {
      final manager = await signedInManager();
      respond = (_) async => jsonResponse(200, tokenPairEnvelope('2'));
      await manager.refresh();

      await manager.handleRejectedSession('access-1');

      expect(manager.status.value, const SignedIn());
    });

    test('a suspension is reported with the server message', () async {
      final manager = await signedInManager();

      manager.handleAccountSuspended('Your account has been suspended.');

      expect(
        manager.status.value,
        const AccountSuspended('Your account has been suspended.'),
      );
    });
  });

  test('sessionStatusProvider follows the session', () async {
    final manager = harness.createManager();
    final container = ProviderContainer.test(
      overrides: [sessionManagerProvider.overrideWithValue(manager)],
    );
    final statuses = <SessionStatus>[];
    container.listen(
      sessionStatusProvider,
      (_, next) => statuses.add(next),
      fireImmediately: true,
    );

    await manager.ready;
    await manager.signIn(validTokens);

    expect(statuses, [
      const SessionRestoring(),
      const SignedOut(SignOutReason.signedOut),
      const SignedIn(),
    ]);
  });
}
