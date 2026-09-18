import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/auth/auth_providers.dart';
import 'package:kinvo/src/core/auth/session_status.dart';
import 'package:kinvo/src/features/auth/presentation/controllers/login_controller.dart';

import '../../../helpers/auth_fixtures.dart';
import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/test_backend.dart';

void main() {
  late TestBackend backend;
  late ProviderContainer container;

  setUp(() {
    backend = TestBackend(
      respond: (_) async => jsonResponse(200, tokenPairEnvelope('1')),
    );
    container = backend.createContainer();
    // The form resets when nothing is listening, so keep it alive.
    container.listen(loginControllerProvider, (_, _) {});
  });

  LoginController form() => container.read(loginControllerProvider.notifier);
  LoginFormState state() => container.read(loginControllerProvider);

  void fillIn() {
    form()
      ..updateEmail('sam@example.com')
      ..updatePassword('correct horse');
  }

  void serverRejects(int status, String code, String message) {
    backend.respond = (_) async =>
        jsonResponse(status, errorEnvelope(code, message));
  }

  test('signs in and stays signed in on this device', () async {
    fillIn();
    expect(state().rememberDevice, isTrue);

    expect(await form().submit(), isTrue);

    expect(backend.requestsTo('/auth/login').single.data, {
      'email': 'sam@example.com',
      'password': 'correct horse',
      'device_id': testDeviceId,
    });
    expect(container.read(sessionStatusProvider), const SignedIn());
    expect(await backend.tokenStore.read(), isNotNull);
  });

  test('without remembering the device, nothing is saved', () async {
    fillIn();
    form().setRememberDevice(false);

    expect(await form().submit(), isTrue);

    expect(container.read(sessionStatusProvider), const SignedIn());
    expect(await backend.tokenStore.read(), isNull);
  });

  test('asks for an email and password before sending anything', () async {
    expect(await form().submit(), isFalse);

    expect(state().errors, {
      LoginField.email: 'Enter your email address.',
      LoginField.password: 'Enter your password.',
    });
    expect(backend.adapter.requests, isEmpty);
  });

  test('explains wrong details without saying which was wrong', () async {
    serverRejects(
      401,
      'AUTH_INVALID_CREDENTIALS',
      'That email or password is incorrect.',
    );
    fillIn();

    expect(await form().submit(), isFalse);

    expect(state().formError, 'That email or password is incorrect.');
    expect(state().errors, isEmpty);
    expect(state().isSubmitting, isFalse);
    expect(
      container.read(sessionStatusProvider),
      const SignedOut(SignOutReason.signedOut),
    );
  });

  test('passes on why a suspended account cannot sign in', () async {
    serverRejects(403, 'ACCOUNT_SUSPENDED', 'Suspended for spamming.');
    fillIn();

    await form().submit();

    expect(state().formError, 'Suspended for spamming.');
  });

  test('says to wait after too many attempts', () async {
    serverRejects(
      429,
      'RATE_LIMITED',
      'Too many sign-in attempts. Please wait a few minutes and try again.',
    );
    fillIn();

    await form().submit();

    expect(
      state().formError,
      'Too many sign-in attempts. Please wait a few minutes and try again.',
    );
  });

  test('editing the form clears the last failure', () async {
    serverRejects(
      401,
      'AUTH_INVALID_CREDENTIALS',
      'That email or password is incorrect.',
    );
    fillIn();
    await form().submit();

    form().updatePassword('correct horse battery');

    expect(state().formError, isNull);
  });
}
