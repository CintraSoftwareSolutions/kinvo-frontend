import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/time/clock.dart';
import 'package:kinvo/src/core/widgets/flow_widgets.dart';
import 'package:kinvo/src/features/auth/data/phone_auth_service.dart';
import 'package:kinvo/src/features/auth/presentation/controllers/phone_sign_in_controller.dart';
import 'package:kinvo/src/features/auth/presentation/screens/login_screen.dart';
import 'package:kinvo/src/features/auth/presentation/screens/phone_sign_in_screen.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';
import 'package:kinvo/src/features/onboarding/presentation/screens/onboarding_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/auth_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_kinvo_server.dart';

/// What the server was asked, so the test can assert the number and code that
/// were really sent.
final class PhoneCalls {
  final List<Map<String, Object?>> sent = [];
  final List<Map<String, Object?>> verified = [];
}

/// A server that texts codes and accepts one of them.
///
/// [refusesNumber] is Twilio refusing to text a number at all — a landline, a
/// typo, or a reserved range that only looks real — which the server reports
/// as a validation error on the field.
FakeResponder server(
  PhoneCalls calls, {
  bool onboarded = true,
  bool isNewUser = false,
  String accepts = '123456',
  bool refusesNumber = false,
}) {
  final backend = FakeKinvoServer()..isOnboarded = onboarded;

  return (options) async {
    final body = switch (options.data) {
      final Map<String, Object?> data => data,
      _ => const <String, Object?>{},
    };

    switch (options.uri.path) {
      case '/api/v1/auth/otp/send':
        calls.sent.add(body);
        if (refusesNumber) {
          return jsonResponse(
            400,
            errorEnvelope(
              'VALIDATION_FAILED',
              'Some fields need attention.',
              details: {
                'phone': [
                  'That number cannot receive a text. Check it and try again.',
                ],
              },
            ),
          );
        }
        return jsonResponse(200, successEnvelope({'sent': true}));

      case '/api/v1/auth/otp/verify':
        calls.verified.add(body);
        if (body['code'] != accepts) {
          return jsonResponse(
            401,
            errorEnvelope(
              'AUTH_INVALID_CREDENTIALS',
              'That code is incorrect or has expired.',
            ),
          );
        }
        final tokens = tokenPairEnvelope('phone');
        return jsonResponse(isNewUser ? 201 : 200, {
          ...tokens,
          'data': {
            ...(tokens['data']! as Map<String, Object?>),
            'is_new_user': isNewUser,
          },
        });

      default:
        return backend.respond(options);
    }
  };
}

Finder field(String label) => find.widgetWithText(AppInputCard, label);

Future<AppHarness> openPhoneSignIn(
  WidgetTester tester,
  FakeResponder respond, {
  Clock? clock,
}) async {
  final app = await pumpKinvoApp(tester, respond: respond, clock: clock);

  await app.pumpUntilFound(find.text('Log In'));
  await tester.tap(find.text('Log In'));
  await tester.pumpAndSettle();
  await app.pumpUntilFound(find.byType(LoginScreen));

  // The button sits below the fold on a phone-sized screen.
  final phoneButton = find.text('Continue with your phone number');
  await tester.ensureVisible(phoneButton);
  await tester.pump();
  await tester.tap(phoneButton);
  await app.pumpUntilFound(find.byType(PhoneSignInScreen));
  return app;
}

void main() {
  group('the number is checked before an SMS is paid for', () {
    test('a number typed the way it is printed is accepted', () {
      expect(PhoneAuthService.looksValid('+44 7700 900123'), isTrue);
      expect(PhoneAuthService.looksValid('+44 (7700) 900-123'), isTrue);
      // 00 is the plus, in most of the world.
      expect(PhoneAuthService.looksValid('0044 7700 900123'), isTrue);
      expect(
        PhoneAuthService.normalisePhone('0044 7700 900123'),
        '+447700900123',
      );
    });

    test('a number with no country code is refused', () {
      expect(PhoneAuthService.looksValid('07700900123'), isFalse);
      expect(PhoneAuthService.looksValid('+0 7700900123'), isFalse);
      expect(PhoneAuthService.looksValid(''), isFalse);
    });
  });

  testWidgets('a code is sent, entered, and signs the user in', (tester) async {
    final calls = PhoneCalls();
    final app = await openPhoneSignIn(tester, server(calls));

    await tester.enterText(field('PHONE NUMBER'), '+44 7700 900123');
    await tester.pump();
    await tester.tap(find.text('Send code'));
    await app.pumpUntilFound(find.text('Enter the code'));

    // Sent in the only format Twilio accepts, whatever was typed.
    expect(calls.sent.single['phone'], '+447700900123');

    await tester.enterText(field('CODE'), '123456');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await app.pumpUntilFound(find.byType(DiscoverScreen));
    await app.pumpUntilLoaded();

    expect(calls.verified.single['code'], '123456');
    expect(calls.verified.single['phone'], '+447700900123');
  });

  testWidgets('a number with no account lands in profile setup', (
    tester,
  ) async {
    final calls = PhoneCalls();
    final app = await openPhoneSignIn(
      tester,
      server(calls, onboarded: false, isNewUser: true),
    );

    await tester.enterText(field('PHONE NUMBER'), '+447700900123');
    await tester.pump();
    await tester.tap(find.text('Send code'));
    await app.pumpUntilFound(find.text('Enter the code'));

    await tester.enterText(field('CODE'), '123456');
    await tester.pump();
    await tester.tap(find.text('Continue'));

    // An account made from a phone number has no date of birth, and
    // onboarding is where that is asked for.
    await app.pumpUntilFound(find.byType(OnboardingScreen));
    await app.pumpUntilFound(find.text('About you'));
  });

  testWidgets('a wrong code says so and stays on the code step', (
    tester,
  ) async {
    final calls = PhoneCalls();
    final app = await openPhoneSignIn(tester, server(calls));

    await tester.enterText(field('PHONE NUMBER'), '+447700900123');
    await tester.pump();
    await tester.tap(find.text('Send code'));
    await app.pumpUntilFound(find.text('Enter the code'));

    await tester.enterText(field('CODE'), '000000');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await app.pumpUntilFound(find.textContaining('incorrect or has expired'));

    expect(find.byType(PhoneSignInScreen), findsOneWidget);
    // Still there to correct, rather than thrown back to the number.
    expect(field('CODE'), findsOneWidget);
  });

  testWidgets('a number the network will not text says why', (tester) async {
    final calls = PhoneCalls();
    final app = await openPhoneSignIn(
      tester,
      server(calls, refusesNumber: true),
    );

    // Looks right, and is not: a UK number reserved for drama, which Twilio
    // refuses. Only the network knows, so only the network can say so.
    await tester.enterText(field('PHONE NUMBER'), '+447700900123');
    await tester.pump();
    await tester.tap(find.text('Send code'));
    await app.pumpUntilFound(find.textContaining('cannot receive a text'));

    // Still on the number, with it there to correct.
    expect(field('PHONE NUMBER'), findsOneWidget);
    expect(find.text('Enter the code'), findsNothing);
  });

  testWidgets('a mistyped number is refused before anything is sent', (
    tester,
  ) async {
    final calls = PhoneCalls();
    final app = await openPhoneSignIn(tester, server(calls));

    await tester.enterText(field('PHONE NUMBER'), '07700900123');
    await tester.pump();

    // The button is not even offered, so no SMS can be paid for by a typo.
    final button = tester.widget<PrimaryActionButton>(
      find.widgetWithText(PrimaryActionButton, 'Send code'),
    );
    expect(button.onPressed, isNull);
    expect(calls.sent, isEmpty);

    await app.pumpUntilLoaded();
  });

  testWidgets('another code cannot be asked for straight away', (tester) async {
    var now = DateTime(2026, 9, 22, 10);
    final calls = PhoneCalls();
    final app = await openPhoneSignIn(tester, server(calls), clock: () => now);

    await tester.enterText(field('PHONE NUMBER'), '+447700900123');
    await tester.pump();
    await tester.tap(find.text('Send code'));
    await app.pumpUntilFound(find.text('Enter the code'));

    // A second code chasing a slow first one is how people end up entering
    // the older of two.
    expect(find.textContaining('Send again in'), findsOneWidget);

    now = now.add(resendCodeAfter);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Send the code again'), findsOneWidget);
    expect(calls.sent, hasLength(1));
  });
}
