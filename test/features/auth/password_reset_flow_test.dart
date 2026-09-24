import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/core/widgets/flow_widgets.dart';
import 'package:kinvo/src/features/auth/presentation/screens/new_password_screen.dart';
import 'package:kinvo/src/features/auth/presentation/screens/password_reset_screen.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/auth_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_kinvo_server.dart';

Finder field(String label) => find.widgetWithText(AppInputCard, label);

void main() {
  late FakeKinvoServer server;

  /// A server that emails the code, as production does, and accepts the
  /// sign-in that follows the reset.
  FakeResponder respond() {
    server = FakeKinvoServer()..isOnboarded = true;
    return (options) async => switch (options.uri.path) {
      '/api/v1/auth/login' => jsonResponse(200, tokenPairEnvelope('1')),
      _ => server.respond(options),
    };
  }

  Future<AppHarness> openLogin(WidgetTester tester) async {
    final app = await pumpKinvoApp(tester, respond: respond());
    await app.pumpUntilFound(find.text('Log In'));
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();
    return app;
  }

  testWidgets('a forgotten password is reset and the app opens', (
    tester,
  ) async {
    final app = await openLogin(tester);

    await tester.enterText(field('EMAIL'), 'sam@example.com');
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    // Carried over from the log-in screen rather than typed again.
    expect(find.byType(PasswordResetScreen), findsOneWidget);
    expect(find.text('sam@example.com'), findsOneWidget);

    await tester.tap(find.text('Send code'));
    await app.pumpUntilFound(find.byType(NewPasswordScreen));

    // A production server keeps the code to the inbox, so nothing on screen
    // can give it away.
    final code = server.resetCodes['sam@example.com']!;
    expect(find.textContaining(code), findsNothing);

    await tester.enterText(field('CODE FROM EMAIL'), code);
    await tester.enterText(field('NEW PASSWORD'), 'a brand new password');
    await tester.tap(find.text('Save new password'));

    await app.pumpUntilFound(find.byType(DiscoverScreen));
    await app.pumpUntilLoaded();
    expect(server.passwordAfterReset, 'a brand new password');
    // Signed in on this device, as someone who has just proved the address is
    // theirs expects to be.
    expect(await app.backend.tokenStore.read(), isNotNull);
  });

  testWidgets('a wrong code is explained and can be tried again', (
    tester,
  ) async {
    final app = await openLogin(tester);

    await tester.enterText(field('EMAIL'), 'sam@example.com');
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send code'));
    await app.pumpUntilFound(find.byType(NewPasswordScreen));

    await tester.enterText(field('CODE FROM EMAIL'), '999999');
    await tester.enterText(field('NEW PASSWORD'), 'a brand new password');
    await tester.tap(find.text('Save new password'));

    await app.pumpUntilFound(
      find.text('That code is wrong or has expired. Please request a new one.'),
    );
    expect(find.byType(NewPasswordScreen), findsOneWidget);
    expect(server.passwordAfterReset, isNull);
  });

  testWidgets('the code step is closed until a code has been asked for', (
    tester,
  ) async {
    final app = await pumpKinvoApp(tester, respond: respond());
    await app.pumpUntilFound(find.text('Log In'));

    app.router.go(AppRoutes.newPassword);
    await tester.pumpAndSettle();

    // A form for a code nobody has sent can only fail, so it sends the user to
    // the step that sends one.
    expect(find.byType(PasswordResetScreen), findsOneWidget);
    expect(find.byType(NewPasswordScreen), findsNothing);
  });

  testWidgets('a server that cannot send email says so, and stays put', (
    tester,
  ) async {
    const refusal =
        'We cannot send email at the moment. Please try again '
        'shortly.';
    final backend = respond();

    // What a deployment whose mail transport is down answers. It is the honest
    // alternative to the generic "a code is on its way", which sends somebody
    // to refresh an inbox nothing was ever sent to — and it says nothing about
    // the address, because the server refuses every address this way.
    final app = await pumpKinvoApp(
      tester,
      respond: (options) async {
        if (options.uri.path == '/api/v1/auth/forgot-password') {
          return jsonResponse(
            503,
            errorEnvelope('SERVICE_UNAVAILABLE', refusal),
          );
        }
        return backend(options);
      },
    );

    await app.pumpUntilFound(find.text('Log In'));
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();
    await tester.enterText(field('EMAIL'), 'sam@example.com');
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send code'));

    await app.pumpUntilFound(find.text(refusal));
    // Still on the step that sends a code: a form for a code that is not
    // coming can only waste the user's time.
    expect(find.byType(PasswordResetScreen), findsOneWidget);
    expect(find.byType(NewPasswordScreen), findsNothing);
    await app.pumpUntilLoaded();
  });
}
