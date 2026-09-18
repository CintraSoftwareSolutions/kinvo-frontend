import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/auth/auth_providers.dart';
import 'package:kinvo/src/core/auth/session_status.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/core/widgets/flow_widgets.dart';
import 'package:kinvo/src/features/auth/presentation/screens/login_screen.dart';
import 'package:kinvo/src/features/auth/presentation/screens/signup_screen.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';
import 'package:kinvo/src/features/more/presentation/screens/settings_screen.dart';
import 'package:kinvo/src/features/onboarding/presentation/screens/onboarding_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/auth_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_kinvo_server.dart';
import '../../helpers/test_backend.dart';

/// A server that accepts every sign-in and knows one account.
FakeResponder server({bool onboarded = true}) {
  final backend = FakeKinvoServer()..isOnboarded = onboarded;
  return (options) async {
    return switch (options.uri.path) {
      '/api/v1/auth/register' => jsonResponse(201, tokenPairEnvelope('new')),
      '/api/v1/auth/login' => jsonResponse(200, tokenPairEnvelope('1')),
      _ => backend.respond(options),
    };
  };
}

Finder field(String label) => find.widgetWithText(AppInputCard, label);

Future<void> openFromWelcome(
  WidgetTester tester,
  AppHarness app,
  String button,
) async {
  await app.pumpUntilFound(find.text(button));
  await tester.tap(find.text(button));
  await tester.pumpAndSettle();
}

/// Taps [label] and lets the dialog it opens finish appearing. Screens behind
/// the dialog may animate forever, so this can't wait for them to settle.
Future<void> tapAndOpenDialog(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('a new account is created and continues to profile setup', (
    tester,
  ) async {
    final app = await pumpKinvoApp(
      tester,
      respond: server(onboarded: false),
      clock: () => DateTime(2026, 9, 15, 10),
    );
    await openFromWelcome(tester, app, 'Create Account');

    await tester.enterText(field('FULL NAME'), 'Sam Taylor');
    await tester.enterText(field('EMAIL'), 'sam@example.com');
    await tester.enterText(field('PASSWORD'), 'correct horse');
    await tester.ensureVisible(find.text('Select your date of birth'));
    await tester.tap(find.text('Select your date of birth'));
    await tester.pumpAndSettle();
    // The picker starts 18 years back, on today's date.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Sep 15, 2008'), findsOneWidget);

    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));

    await app.pumpUntilFound(find.byType(OnboardingScreen));
    await app.pumpUntilFound(find.text('About you'));
    expect(app.backend.requestsTo('/auth/register').single.data, {
      'display_name': 'Sam Taylor',
      'email': 'sam@example.com',
      'password': 'correct horse',
      'date_of_birth': '2008-09-15',
      'device_id': testDeviceId,
    });
  });

  testWidgets('mistakes are pointed out before anything is sent', (
    tester,
  ) async {
    final app = await pumpKinvoApp(tester, respond: server());
    await openFromWelcome(tester, app, 'Create Account');

    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your name.'), findsOneWidget);
    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter a password.'), findsOneWidget);
    expect(find.text('Enter your date of birth.'), findsOneWidget);
    expect(app.adapter.requests, isEmpty);
  });

  testWidgets('logging in opens the app', (tester) async {
    final app = await pumpKinvoApp(tester, respond: server());
    await openFromWelcome(tester, app, 'Log In');

    await tester.enterText(field('EMAIL'), 'sam@example.com');
    await tester.enterText(field('PASSWORD'), 'correct horse');
    await tester.tap(find.text('Sign in'));

    await app.pumpUntilFound(find.byType(DiscoverScreen));
    await app.pumpUntilLoaded();
    expect(await app.backend.tokenStore.read(), isNotNull);
  });

  testWidgets('wrong details are explained on the log-in screen', (
    tester,
  ) async {
    final app = await pumpKinvoApp(
      tester,
      respond: (_) async => jsonResponse(
        401,
        errorEnvelope(
          'AUTH_INVALID_CREDENTIALS',
          'That email or password is incorrect.',
        ),
      ),
    );
    await openFromWelcome(tester, app, 'Log In');

    await tester.enterText(field('EMAIL'), 'sam@example.com');
    await tester.enterText(field('PASSWORD'), 'wrong password');
    await tester.tap(find.text('Sign in'));

    await app.pumpUntilFound(find.text('That email or password is incorrect.'));
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('screen readers hear what each control is', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await pumpKinvoApp(tester);
    await openFromWelcome(tester, app, 'Log In');

    expect(
      tester.getSemantics(find.bySemanticsLabel('EMAIL')),
      isSemantics(label: 'EMAIL', isTextField: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Remember this device')),
      isSemantics(hasCheckedState: true, isChecked: true, hasTapAction: true),
    );

    app.router.go(AppRoutes.signup);
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.bySemanticsLabel('DATE OF BIRTH')),
      isSemantics(
        isButton: true,
        value: 'Select your date of birth',
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('production builds offer only email sign-in', (tester) async {
    final app = await pumpKinvoApp(tester, demoAvailable: false);
    await openFromWelcome(tester, app, 'Log In');

    expect(field('EMAIL'), findsOneWidget);
    // Resetting a password is a real flow, so it is not demo-only.
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('QUICK ACCESS'), findsNothing);

    app.router.go(AppRoutes.signup);
    await tester.pumpAndSettle();

    expect(find.byType(SignupScreen), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('Continue with Apple'), findsNothing);
  });

  testWidgets('demo builds keep the prototype sign-in options', (tester) async {
    final app = await pumpKinvoApp(tester);
    await openFromWelcome(tester, app, 'Log In');

    expect(find.text('QUICK ACCESS'), findsOneWidget);

    app.router.go(AppRoutes.signup);
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('logging out from settings returns to the welcome screen', (
    tester,
  ) async {
    final app = await pumpKinvoApp(
      tester,
      savedSession: liveSession(),
      respond: server(),
    );
    await app.pumpUntilFound(find.byType(DiscoverScreen));
    await app.pumpUntilLoaded();
    app.router.go(AppRoutes.settings);
    await app.pumpUntilFound(find.byType(SettingsScreen));

    await tapAndOpenDialog(tester, find.text('Log out'));
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));

    await app.pumpUntilFound(find.text('Create Account'));
    expect(await app.backend.tokenStore.read(), isNull);
    expect(app.backend.requestsTo('/auth/logout'), hasLength(1));
  });

  testWidgets('a new account can log out of profile setup', (tester) async {
    final server = FakeKinvoServer();
    final app = await pumpKinvoApp(
      tester,
      savedSession: liveSession(),
      respond: server.respond,
    );
    await app.pumpUntilFound(find.text('About you'));

    await tapAndOpenDialog(tester, find.text('Log out'));
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));

    await app.pumpUntilFound(find.text('Create Account'));
  });

  testWidgets('leaving the demo from settings returns to the welcome screen', (
    tester,
  ) async {
    final app = await pumpKinvoApp(tester);
    await openFromWelcome(tester, app, 'Explore Demo');
    app.router.go(AppRoutes.settings);
    await app.pumpUntilFound(find.byType(SettingsScreen));

    // There's no account behind the demo to delete.
    expect(find.text('Delete Account'), findsNothing);

    await tapAndOpenDialog(tester, find.text('Log out'));
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));

    await app.pumpUntilFound(find.text('Create Account'));
  });

  testWidgets('deleting the account signs out and says so', (tester) async {
    final app = await pumpKinvoApp(
      tester,
      savedSession: liveSession(),
      respond: server(),
    );
    await app.pumpUntilFound(find.byType(DiscoverScreen));
    await app.pumpUntilLoaded();
    app.router.go(AppRoutes.settings);
    await app.pumpUntilFound(find.byType(SettingsScreen));

    await tapAndOpenDialog(tester, find.text('Delete Account'));
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));

    await app.pumpUntilFound(find.text('Create Account'));
    expect(find.text('Your account has been deleted.'), findsOneWidget);
    expect(app.backend.requestsTo('/users/me').single.method, 'DELETE');
    expect(await app.backend.tokenStore.read(), isNull);
  });

  testWidgets('a failed deletion is explained and the account kept', (
    tester,
  ) async {
    final app = await pumpKinvoApp(
      tester,
      savedSession: liveSession(),
      respond: (options) {
        if (options.method == 'DELETE') {
          throw const SocketException('Network is unreachable');
        }
        return server()(options);
      },
    );
    await app.pumpUntilFound(find.byType(DiscoverScreen));
    await app.pumpUntilLoaded();
    app.router.go(AppRoutes.settings);
    await app.pumpUntilFound(find.byType(SettingsScreen));

    await tapAndOpenDialog(tester, find.text('Delete Account'));
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));

    await app.pumpUntilFound(
      find.textContaining('Check your internet connection'),
    );
    expect(find.text('Delete your account?'), findsOneWidget);
    expect(app.container.read(sessionStatusProvider), const SignedIn());
  });

  testWidgets('when the server ends the session, the user is told why', (
    tester,
  ) async {
    final app = await pumpKinvoApp(
      tester,
      savedSession: liveSession(),
      respond: (options) async {
        if (options.uri.path.endsWith('/auth/me')) {
          return jsonResponse(
            401,
            errorEnvelope(
              'AUTH_TOKEN_INVALID',
              'Your session is no longer valid.',
            ),
          );
        }
        return jsonResponse(200, successEnvelope(<String, Object?>{}));
      },
    );

    await app.pumpUntilFound(find.text('Create Account'));
    expect(
      find.text('Your session has ended. Please log in again.'),
      findsOneWidget,
    );
  });
}
