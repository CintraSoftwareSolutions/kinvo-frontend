import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/auth/auth_providers.dart';
import 'package:kinvo/src/core/auth/session_status.dart';
import 'package:kinvo/src/features/auth/data/password_reset_service.dart';
import 'package:kinvo/src/features/auth/presentation/controllers/new_password_controller.dart';
import 'package:kinvo/src/features/auth/presentation/controllers/password_reset_controller.dart';

import '../../../helpers/auth_fixtures.dart';
import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fake_kinvo_server.dart';
import '../../../helpers/test_backend.dart';

void main() {
  late FakeKinvoServer server;
  late TestBackend backend;
  late ProviderContainer container;
  late DateTime now;

  setUp(() {
    now = DateTime(2026, 9, 16, 10);
    server = FakeKinvoServer()..returnsResetCode = true;
    backend = TestBackend(
      respond: (options) async => switch (options.uri.path) {
        '/api/v1/auth/login' => jsonResponse(200, tokenPairEnvelope('1')),
        _ => server.respond(options),
      },
    );
    container = backend.createContainer(clock: () => now);
    // The forms reset when nothing is listening, so keep them alive.
    container
      ..listen(resetRequestControllerProvider, (_, _) {})
      ..listen(newPasswordControllerProvider, (_, _) {});
  });

  ResetRequestController request() {
    return container.read(resetRequestControllerProvider.notifier);
  }

  NewPasswordController newPassword() {
    return container.read(newPasswordControllerProvider.notifier);
  }

  PendingPasswordReset? pending() {
    return container.read(pendingPasswordResetProvider);
  }

  /// Goes through the first step, leaving a code outstanding.
  Future<String> askForCode({String email = 'sam@example.com'}) async {
    request().updateEmail(email);
    expect(await request().submit(), isTrue);
    return server.resetCodes[email.trim().toLowerCase()]!;
  }

  group('asking for a code', () {
    test('sends one and remembers where it went', () async {
      final code = await askForCode(email: '  Sam@Example.com  ');

      // Sent without the spaces around it; the server lower-cases it.
      expect(backend.requestsTo('/auth/forgot-password').single.data, {
        'email': 'Sam@Example.com',
      });
      expect(pending()?.email, 'Sam@Example.com');
      expect(pending()?.sentAt, now);
      // Only a server with nowhere to send it answers with the code.
      expect(pending()?.code, code);
    });

    test('checks the address before sending anything', () async {
      request().updateEmail('not-an-address');

      expect(await request().submit(), isFalse);
      expect(container.read(resetRequestControllerProvider).errors, {
        ResetRequestField.email: 'Enter a valid email address.',
      });
      expect(backend.adapter.requests, isEmpty);
      expect(pending(), isNull);
    });

    test('passes on what the server says when it refuses', () async {
      backend.respond = (_) async => jsonResponse(
        429,
        errorEnvelope(
          'RATE_LIMITED',
          'Too many reset requests. Please check your inbox and try again later.',
        ),
      );

      request().updateEmail('sam@example.com');
      expect(await request().submit(), isFalse);

      expect(
        container.read(resetRequestControllerProvider).formError,
        'Too many reset requests. Please check your inbox and try again later.',
      );
      expect(pending(), isNull);
    });
  });

  group('choosing a new password', () {
    test('sets it, signs in, and ends the flow', () async {
      final code = await askForCode();

      newPassword()
        ..updateCode(code)
        ..updatePassword('a brand new password');

      expect(await newPassword().submit(), PasswordResetOutcome.signedIn);

      expect(backend.requestsTo('/auth/reset-password').single.data, {
        'email': 'sam@example.com',
        'code': code,
        'password': 'a brand new password',
      });
      // Signed in with the password just chosen, not the forgotten one.
      expect(backend.requestsTo('/auth/login').single.data, {
        'email': 'sam@example.com',
        'password': 'a brand new password',
        'device_id': testDeviceId,
      });
      expect(container.read(sessionStatusProvider), const SignedIn());
      expect(pending(), isNull);
    });

    test('a changed password that cannot sign in still counts', () async {
      final code = await askForCode();
      backend.respond = (options) async => switch (options.uri.path) {
        '/api/v1/auth/login' => jsonResponse(
          429,
          errorEnvelope('RATE_LIMITED', 'Too many sign-in attempts.'),
        ),
        _ => server.respond(options),
      };

      newPassword()
        ..updateCode(code)
        ..updatePassword('a brand new password');

      // The password IS the new one by then. Reporting failure would send the
      // user back for a code that has already been spent.
      expect(await newPassword().submit(), PasswordResetOutcome.signInRequired);
      expect(container.read(sessionStatusProvider), isNot(const SignedIn()));
      expect(pending(), isNull);
    });

    test('checks the code and the password before sending', () async {
      await askForCode();

      newPassword()
        ..updateCode('12')
        ..updatePassword('short');

      expect(await newPassword().submit(), isNull);
      expect(container.read(newPasswordControllerProvider).errors, {
        NewPasswordField.code: 'Enter the 6-digit code from your email.',
        NewPasswordField.password: 'Use at least 8 characters.',
      });
      expect(backend.requestsTo('/auth/reset-password'), isEmpty);
    });

    test('puts a refused code under the field it belongs to', () async {
      await askForCode();

      newPassword()
        ..updateCode('999999')
        ..updatePassword('a brand new password');

      expect(await newPassword().submit(), isNull);
      expect(container.read(newPasswordControllerProvider).errors, {
        NewPasswordField.code:
            'That code is wrong or has expired. Please request a new one.',
      });
      // Still in the flow: the user can try the code again or ask for another.
      expect(pending(), isNotNull);
    });
  });

  group('asking for another code', () {
    test('waits before spending the account\'s hourly allowance', () async {
      await askForCode();
      await newPassword().resend();

      expect(backend.requestsTo('/auth/forgot-password'), hasLength(1));
      expect(
        container.read(newPasswordControllerProvider).formError,
        'Check your inbox first. You can ask for another code in a moment.',
      );
    });

    test('sends a new one and drops the code that it retires', () async {
      final first = await askForCode();
      newPassword().updateCode(first);

      now = now.add(resendCodeCooldown);
      await newPassword().resend();

      expect(backend.requestsTo('/auth/forgot-password'), hasLength(2));
      final form = container.read(newPasswordControllerProvider);
      expect(form.code, isEmpty);
      expect(form.notice, 'A new code is on its way.');
      expect(pending()?.sentAt, now);
      expect(pending()?.code, isNot(first));
    });
  });
}
