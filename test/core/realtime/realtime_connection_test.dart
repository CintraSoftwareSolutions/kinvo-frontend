import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/auth/session_manager.dart';
import 'package:kinvo/src/core/auth/session_status.dart';
import 'package:kinvo/src/core/network/api_error_code.dart';
import 'package:kinvo/src/core/realtime/realtime_connection.dart';
import 'package:kinvo/src/core/realtime/realtime_events.dart';
import 'package:kinvo/src/core/realtime/realtime_socket.dart';

import '../../helpers/auth_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_realtime_server.dart';

void main() {
  final now = DateTime.utc(2026, 9, 15, 12);

  late SessionHarness harness;
  late FakeRealtimeServer server;
  late int refreshes;

  setUp(() {
    refreshes = 0;
    harness = SessionHarness(
      now: now,
      respond: (options) async {
        if (options.uri.path == '/api/v1/auth/refresh') {
          refreshes++;
          return jsonResponse(200, tokenPairEnvelope('${refreshes + 1}'));
        }
        return jsonResponse(404, errorEnvelope('NOT_FOUND', 'No.'));
      },
    );
    server = FakeRealtimeServer();
  });

  /// Runs [body] on fake time, with a session restored when [signedIn].
  void withSession(
    void Function(FakeAsync async, SessionManager session) body, {
    bool signedIn = true,
  }) {
    fakeAsync((async) {
      if (signedIn) {
        unawaited(
          harness.saveSession(
            testTokens('1', expiresAt: now.add(const Duration(minutes: 30))),
          ),
        );
        async.flushMicrotasks();
      }
      final session = harness.createManager();
      async.flushMicrotasks();
      body(async, session);
    });
  }

  RealtimeConnection connect(
    SessionManager session, {
    Duration Function(int failures)? retryDelay,
  }) {
    final connection = RealtimeConnection(
      session: session,
      createSocket: server.createSocket,
      retryDelay: retryDelay ?? (_) => const Duration(seconds: 1),
    );
    addTearDown(connection.dispose);
    return connection;
  }

  /// Lets requests and handshakes in progress finish.
  void settleOn(FakeAsync async) => async.elapse(Duration.zero);

  RealtimeRefusal refusal(ApiErrorCode code, [String message = 'No.']) {
    return RealtimeRefusal(code: code, message: message);
  }

  group('connecting', () {
    test("uses the session's access token, once wanted", () {
      withSession((async, session) {
        final connection = connect(session);
        settleOn(async);
        expect(connection.status.value, RealtimeStatus.disconnected);
        expect(server.attempts, isEmpty);

        connection.setWanted(true);
        expect(connection.status.value, RealtimeStatus.connecting);
        settleOn(async);

        expect(server.attempts, ['access-1']);
        expect(connection.status.value, RealtimeStatus.connected);
      });
    });

    test('stays closed without a session', () {
      withSession(signedIn: false, (async, session) {
        final connection = connect(session)..setWanted(true);
        settleOn(async);

        expect(server.attempts, isEmpty);
        expect(connection.status.value, RealtimeStatus.disconnected);
      });
    });

    test('never finishes an attempt abandoned on the way', () {
      withSession((async, session) {
        final connection = connect(session)
          ..setWanted(true)
          ..setWanted(false);
        settleOn(async);

        expect(server.attempts, isEmpty);
        expect(server.isConnected, isFalse);
        expect(connection.status.value, RealtimeStatus.disconnected);
      });
    });
  });

  group('closing', () {
    test('happens at once when the connection is not wanted', () {
      withSession((async, session) {
        final connection = connect(session)..setWanted(true);
        settleOn(async);

        connection.setWanted(false);

        expect(connection.status.value, RealtimeStatus.disconnected);
        expect(server.isConnected, isFalse);
      });
    });

    test('waits out a grace period, and is called off if wanted again', () {
      withSession((async, session) {
        final connection = connect(session)..setWanted(true);
        settleOn(async);

        connection.setWanted(false, grace: const Duration(seconds: 30));
        async.elapse(const Duration(seconds: 29));
        expect(server.isConnected, isTrue);

        connection.setWanted(true);
        async.elapse(const Duration(minutes: 1));
        expect(server.isConnected, isTrue);
        expect(server.attempts, hasLength(1));

        connection.setWanted(false, grace: const Duration(seconds: 30));
        async.elapse(const Duration(seconds: 30));
        expect(server.isConnected, isFalse);
        expect(connection.status.value, RealtimeStatus.disconnected);
      });
    });
  });

  group('refused', () {
    test('as expired: refreshes the token and connects straight away', () {
      withSession((async, session) {
        server.refuse = (token) =>
            token == 'access-1' ? refusal(ApiErrorCode.authTokenExpired) : null;

        final connection = connect(session)..setWanted(true);
        settleOn(async);

        expect(refreshes, 1);
        expect(server.attempts, ['access-1', 'access-2']);
        expect(connection.status.value, RealtimeStatus.connected);
      });
    });

    test('as expired again after refreshing: waits before trying again', () {
      withSession((async, session) {
        server.refuse = (_) => refusal(ApiErrorCode.authTokenExpired);

        final connection = connect(session)..setWanted(true);
        settleOn(async);

        // One refresh an attempt, never a loop of them.
        expect(server.attempts, ['access-1', 'access-2']);
        expect(refreshes, 1);
        expect(connection.status.value, RealtimeStatus.connecting);

        async.elapse(const Duration(seconds: 1));
        expect(server.attempts, [
          'access-1',
          'access-2',
          'access-2',
          'access-3',
        ]);
        expect(refreshes, 2);
      });
    });

    test('as invalid: ends the session and stops trying', () {
      withSession((async, session) {
        server.refuse = (_) => refusal(ApiErrorCode.authTokenInvalid);

        final connection = connect(session)..setWanted(true);
        settleOn(async);
        async.elapse(const Duration(minutes: 5));

        expect(
          session.status.value,
          const SignedOut(SignOutReason.sessionEnded),
        );
        expect(server.attempts, ['access-1']);
        expect(connection.status.value, RealtimeStatus.disconnected);
      });
    });

    test('as suspended: marks the account suspended and stops trying', () {
      withSession((async, session) {
        server.refuse = (_) => refusal(
          ApiErrorCode.accountSuspended,
          'Your account is suspended.',
        );

        final connection = connect(session)..setWanted(true);
        settleOn(async);
        async.elapse(const Duration(minutes: 5));

        expect(
          session.status.value,
          const AccountSuspended('Your account is suspended.'),
        );
        expect(server.attempts, hasLength(1));
        expect(connection.status.value, RealtimeStatus.disconnected);
      });
    });

    test(
      'for an account still being set up: tries again once wanted again',
      () {
        withSession((async, session) {
          server.refuse = (_) => refusal(ApiErrorCode.onboardingIncomplete);

          final connection = connect(session)..setWanted(true);
          settleOn(async);
          async.elapse(const Duration(minutes: 5));
          expect(server.attempts, hasLength(1));

          server.refuse = null;
          connection.setWanted(true);
          settleOn(async);

          expect(server.attempts, hasLength(2));
          expect(connection.status.value, RealtimeStatus.connected);
        });
      },
    );
  });

  group('trying again', () {
    test('waits longer after each failure, and starts over once connected', () {
      withSession((async, session) {
        final waits = <int>[];
        server.reachable = false;
        final connection = connect(
          session,
          retryDelay: (failures) {
            waits.add(failures);
            return Duration(seconds: failures + 1);
          },
        )..setWanted(true);
        settleOn(async);
        expect(server.attempts, hasLength(1));

        async.elapse(const Duration(seconds: 1));
        expect(server.attempts, hasLength(2));
        async.elapse(const Duration(seconds: 2));
        expect(server.attempts, hasLength(3));

        server.reachable = true;
        async.elapse(const Duration(seconds: 3));
        expect(server.attempts, hasLength(4));
        expect(connection.status.value, RealtimeStatus.connected);
        expect(waits, [0, 1, 2]);

        // A dropped connection comes back after the shortest wait.
        server.dropConnections();
        expect(connection.status.value, RealtimeStatus.connecting);
        async.elapse(const Duration(seconds: 1));
        expect(server.attempts, hasLength(5));
        expect(connection.status.value, RealtimeStatus.connected);
        expect(waits, [0, 1, 2, 0]);
      });
    });

    test('by default waits about a second at first, and never over 30', () {
      for (var i = 0; i < 20; i++) {
        final first = RealtimeConnection.defaultRetryDelay(0);
        expect(first.inMilliseconds, inInclusiveRange(800, 1200));

        final later = RealtimeConnection.defaultRetryDelay(3);
        expect(later.inMilliseconds, inInclusiveRange(6400, 9600));

        final longest = RealtimeConnection.defaultRetryDelay(50);
        expect(longest, lessThanOrEqualTo(RealtimeConnection.maxRetryDelay));
        expect(longest.inSeconds, greaterThanOrEqualTo(24));
      }
    });
  });

  group('while connected', () {
    test('passes on what the server sends', () {
      withSession((async, session) {
        final connection = connect(session)..setWanted(true);
        final events = <RealtimeEvent>[];
        final subscription = connection.events.listen(events.add);
        addTearDown(subscription.cancel);
        settleOn(async);

        server.push(ServerEvents.typing, {'conversation_id': 'c1'});
        async.flushMicrotasks();

        expect(events.single.name, ServerEvents.typing);
        expect(events.single.data, {'conversation_id': 'c1'});
      });
    });

    test('sends only while open', () {
      withSession((async, session) {
        final connection = connect(session)
          ..send(ClientEvents.typingStart, {'conversation_id': 'early'})
          ..setWanted(true);
        settleOn(async);

        connection.send(ClientEvents.typingStart, {'conversation_id': 'c1'});
        connection
          ..setWanted(false)
          ..send(ClientEvents.typingStart, {'conversation_id': 'late'});

        expect(server.sent(ClientEvents.typingStart), [
          {'conversation_id': 'c1'},
        ]);
      });
    });

    test('tells the server the user is active every minute', () {
      withSession((async, session) {
        final connection = connect(session)..setWanted(true);
        settleOn(async);

        async.elapse(const Duration(minutes: 2));
        expect(server.sent(ClientEvents.presencePing), hasLength(2));

        connection.setWanted(false);
        async.elapse(const Duration(minutes: 2));
        expect(server.sent(ClientEvents.presencePing), hasLength(2));
        expect(async.periodicTimerCount, 0);
      });
    });
  });

  test('disposing closes the socket for good', () {
    withSession((async, session) {
      final connection = RealtimeConnection(
        session: session,
        createSocket: server.createSocket,
      )..setWanted(true);
      settleOn(async);

      connection.dispose();
      async.elapse(const Duration(minutes: 5));

      expect(server.sockets.single.isDisposed, isTrue);
      expect(server.attempts, hasLength(1));
      expect(async.periodicTimerCount, 0);
    });
  });
}
