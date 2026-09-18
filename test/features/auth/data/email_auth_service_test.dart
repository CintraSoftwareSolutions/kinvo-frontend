import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/auth/auth_api.dart';
import 'package:kinvo/src/core/auth/session_manager.dart';
import 'package:kinvo/src/core/auth/session_status.dart';
import 'package:kinvo/src/core/device/client_info.dart';
import 'package:kinvo/src/core/network/api_client.dart';
import 'package:kinvo/src/core/network/api_error_code.dart';
import 'package:kinvo/src/core/network/api_exception.dart';
import 'package:kinvo/src/core/time/calendar_date.dart';
import 'package:kinvo/src/features/auth/data/email_auth_service.dart';

import '../../../helpers/auth_fixtures.dart';
import '../../../helpers/fake_http_adapter.dart';

void main() {
  late FakeResponder respond;
  late SessionHarness harness;
  late SessionManager session;
  late EmailAuthService service;

  setUp(() async {
    respond = (_) async => jsonResponse(200, tokenPairEnvelope('new'));
    harness = SessionHarness(respond: (options) => respond(options));
    session = harness.createManager();
    await session.ready;
    service = EmailAuthService(
      api: AuthApi(ApiClient(harness.publicDio), clock: harness.clock.call),
      session: session,
      clientInfo: () async => const ClientInfo(
        deviceId: 'device-1',
        platform: ClientPlatform.ios,
        appVersion: '1.0.0+1',
      ),
    );
  });

  Matcher throwsApiError(ApiErrorCode code) {
    return throwsA(
      isA<ApiErrorException>().having((error) => error.code, 'code', code),
    );
  }

  group('register', () {
    test('creates the account for this device and signs in to it', () async {
      await service.register(
        displayName: '  Sam Taylor ',
        email: ' sam@example.com ',
        password: ' spaces count ',
        dateOfBirth: CalendarDate(1995, 7, 4),
      );

      expect(harness.requestsTo('/auth/register').single.data, {
        'display_name': 'Sam Taylor',
        'email': 'sam@example.com',
        'password': ' spaces count ',
        'date_of_birth': '1995-07-04',
        'device_id': 'device-1',
      });
      expect(session.status.value, const SignedIn());
      expect((await harness.store.read())?.accessToken, 'access-new');
    });

    test('stays signed out when the server refuses', () async {
      respond = (_) async => jsonResponse(
        409,
        errorEnvelope('CONFLICT', 'An account with that email already exists.'),
      );

      await expectLater(
        service.register(
          displayName: 'Sam Taylor',
          email: 'sam@example.com',
          password: 'correct horse',
          dateOfBirth: CalendarDate(1995, 7, 4),
        ),
        throwsApiError(ApiErrorCode.conflict),
      );

      expect(session.status.value, const SignedOut(SignOutReason.signedOut));
      expect(await harness.store.read(), isNull);
    });
  });

  group('login', () {
    test('signs in for this device and remembers the session', () async {
      await service.login(
        email: ' sam@example.com',
        password: 'correct horse',
        remember: true,
      );

      expect(harness.requestsTo('/auth/login').single.data, {
        'email': 'sam@example.com',
        'password': 'correct horse',
        'device_id': 'device-1',
      });
      expect(session.status.value, const SignedIn());
      expect((await harness.store.read())?.accessToken, 'access-new');
    });

    test('keeps a session it should not remember off the device', () async {
      await service.login(
        email: 'sam@example.com',
        password: 'correct horse',
        remember: false,
      );

      expect(session.status.value, const SignedIn());
      expect(await harness.store.read(), isNull);
    });

    test('stays signed out when the details are wrong', () async {
      respond = (_) async => jsonResponse(
        401,
        errorEnvelope(
          'AUTH_INVALID_CREDENTIALS',
          'That email or password is incorrect.',
        ),
      );

      await expectLater(
        service.login(
          email: 'sam@example.com',
          password: 'wrong',
          remember: true,
        ),
        throwsApiError(ApiErrorCode.authInvalidCredentials),
      );

      expect(session.status.value, const SignedOut(SignOutReason.signedOut));
    });
  });
}
