import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/auth/auth_providers.dart';
import 'package:kinvo/src/core/auth/session_status.dart';
import 'package:kinvo/src/core/time/calendar_date.dart';
import 'package:kinvo/src/features/auth/presentation/controllers/signup_controller.dart';

import '../../../helpers/auth_fixtures.dart';
import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/test_backend.dart';

void main() {
  late TestBackend backend;
  late ProviderContainer container;

  setUp(() {
    backend = TestBackend(
      respond: (_) async => jsonResponse(201, tokenPairEnvelope('new')),
    );
    container = backend.createContainer(clock: () => DateTime(2026, 9, 15, 10));
    // The form resets when nothing is listening, so keep it alive.
    container.listen(signupControllerProvider, (_, _) {});
  });

  SignupController form() => container.read(signupControllerProvider.notifier);
  SignupFormState state() => container.read(signupControllerProvider);

  void fillIn({String password = 'correct horse', CalendarDate? dateOfBirth}) {
    form()
      ..updateDisplayName('Sam Taylor')
      ..updateEmail('sam@example.com')
      ..updatePassword(password)
      ..updateDateOfBirth(dateOfBirth ?? CalendarDate(1995, 7, 4));
  }

  test('creates the account and signs in', () async {
    fillIn();

    expect(await form().submit(), isTrue);

    expect(backend.requestsTo('/auth/register').single.data, {
      'display_name': 'Sam Taylor',
      'email': 'sam@example.com',
      'password': 'correct horse',
      'date_of_birth': '1995-07-04',
      'device_id': testDeviceId,
    });
    expect(container.read(sessionStatusProvider), const SignedIn());
  });

  test('checks every field before sending anything', () async {
    form().updateEmail('sam@');

    expect(await form().submit(), isFalse);

    expect(state().errors, {
      SignupField.displayName: 'Enter your name.',
      SignupField.email: 'Enter a valid email address.',
      SignupField.password: 'Enter a password.',
      SignupField.dateOfBirth: 'Enter your date of birth.',
    });
    expect(backend.adapter.requests, isEmpty);
  });

  test('does not point out mistakes before the first attempt', () {
    form().updateEmail('sam@');

    expect(state().errors, isEmpty);
  });

  test('turns away anyone under 18 on the day they sign up', () async {
    fillIn(dateOfBirth: CalendarDate(2008, 9, 16));

    expect(await form().submit(), isFalse);
    expect(state().errors, {
      SignupField.dateOfBirth: 'You must be at least 18 to use Kinvo.',
    });

    form().updateDateOfBirth(CalendarDate(2008, 9, 15));
    expect(state().errors, isEmpty);
  });

  test('after an attempt, fixing a field clears its error', () async {
    fillIn(password: 'short');
    await form().submit();
    expect(state().errors, {
      SignupField.password: 'Use at least 8 characters.',
    });

    form().updatePassword('long enough');

    expect(state().errors, isEmpty);
  });

  test("shows the server's field errors under their fields", () async {
    backend.respond = (_) async => jsonResponse(
      400,
      errorEnvelope(
        'VALIDATION_FAILED',
        'Some fields need attention.',
        details: {
          'email': ['Enter a valid email address.'],
          'date_of_birth': ['You must be at least 18 to use Kinvo.'],
        },
      ),
    );
    fillIn();

    expect(await form().submit(), isFalse);

    expect(state().errors, {
      SignupField.email: 'Enter a valid email address.',
      SignupField.dateOfBirth: 'You must be at least 18 to use Kinvo.',
    });
    expect(state().formError, isNull);
    expect(state().isSubmitting, isFalse);
    expect(
      container.read(sessionStatusProvider),
      const SignedOut(SignOutReason.signedOut),
    );
  });

  test('an email that is already registered is flagged on its field', () async {
    const taken =
        'An account with that email already exists. Try signing in, or reset '
        'your password.';
    backend.respond = (_) async =>
        jsonResponse(409, errorEnvelope('CONFLICT', taken));
    fillIn();

    await form().submit();
    expect(state().errors, {SignupField.email: taken});

    form().updateEmail('sam.taylor@example.com');
    expect(state().errors, isEmpty);
  });

  test('explains a failure that is not about a field, then retries', () async {
    backend.respond = (_) => throw const SocketException('offline');
    fillIn();

    expect(await form().submit(), isFalse);
    expect(state().formError, contains('Check your internet connection'));
    expect(state().isSubmitting, isFalse);

    backend.respond = (_) async => jsonResponse(201, tokenPairEnvelope('new'));
    expect(await form().submit(), isTrue);
    expect(state().formError, isNull);
  });

  test('sends one request however often it is submitted', () async {
    final response = Completer<ResponseBody>();
    backend.respond = (_) => response.future;
    fillIn();

    final first = form().submit();
    final second = form().submit();
    expect(state().isSubmitting, isTrue);
    response.complete(jsonResponse(201, tokenPairEnvelope('new')));

    expect(await second, isFalse);
    expect(await first, isTrue);
    expect(backend.requestsTo('/auth/register'), hasLength(1));
  });
}
