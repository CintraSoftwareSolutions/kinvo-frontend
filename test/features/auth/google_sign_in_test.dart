import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/auth/google_identity.dart';
import 'package:kinvo/src/features/auth/presentation/screens/login_screen.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';
import 'package:kinvo/src/features/onboarding/presentation/screens/onboarding_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/auth_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_kinvo_server.dart';

/// What the server was sent, so the test can check the token really travelled.
final class GoogleCalls {
  final List<Map<String, Object?>> signIns = [];
}

/// A server that accepts a Google token.
FakeResponder server(
  GoogleCalls calls, {
  bool onboarded = true,
  bool isNewUser = false,
  int status = 200,
  String? errorCode,
}) {
  final backend = FakeKinvoServer()..isOnboarded = onboarded;

  return (options) async {
    if (options.uri.path == '/api/v1/auth/google') {
      calls.signIns.add(switch (options.data) {
        final Map<String, Object?> data => data,
        _ => const <String, Object?>{},
      });

      if (errorCode case final code?) {
        return jsonResponse(
          status,
          errorEnvelope(code, 'That Google sign-in could not be verified.'),
        );
      }

      final tokens = tokenPairEnvelope('google');
      return jsonResponse(isNewUser ? 201 : 200, {
        ...tokens,
        'data': {
          ...(tokens['data']! as Map<String, Object?>),
          'is_new_user': isNewUser,
        },
      });
    }
    return backend.respond(options);
  };
}

Future<AppHarness> openLogin(WidgetTester tester, FakeResponder respond) async {
  final app = await pumpKinvoApp(tester, respond: respond);

  await app.pumpUntilFound(find.text('Log In'));
  await tester.tap(find.text('Log In'));
  await app.pumpUntilFound(find.byType(LoginScreen));
  return app;
}

/// The Google button, which sits below the fold on a phone-sized screen.
Future<void> tapGoogle(WidgetTester tester) async {
  final button = find.text('Continue with Google');
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
}

void main() {
  testWidgets('a Google account that already has one signs straight in', (
    tester,
  ) async {
    final calls = GoogleCalls();
    final app = await openLogin(tester, server(calls));

    await tapGoogle(tester);
    await app.pumpUntilFound(find.byType(DiscoverScreen));
    await app.pumpUntilLoaded();

    // The token Google gave is what was sent: the app never inspects it.
    expect(calls.signIns.single['id_token'], 'google-id-token');
    expect(calls.signIns.single['device_id'], isNotEmpty);
    expect(await app.backend.tokenStore.read(), isNotNull);
  });

  testWidgets('a Google account with no Kinvo account lands in profile setup', (
    tester,
  ) async {
    final calls = GoogleCalls();
    final app = await openLogin(
      tester,
      server(calls, onboarded: false, isNewUser: true),
    );

    await tapGoogle(tester);
    await app.pumpUntilFound(find.byType(OnboardingScreen));
    await app.pumpUntilFound(find.text('About you'));

    // Google sends the name only the first time, so it is passed on.
    expect(calls.signIns.single['display_name'], 'Sam Google');
  });

  testWidgets('backing out of Google says nothing at all', (tester) async {
    final calls = GoogleCalls();
    final app = await openLogin(tester, server(calls));
    app.backend.googleIdentity.nextAccount = null;

    await tapGoogle(tester);
    await app.pumpUntilLoaded();

    // Not a failure: they changed their mind.
    expect(calls.signIns, isEmpty);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.textContaining('Google'), findsWidgets);
    expect(find.textContaining('Could not'), findsNothing);
  });

  testWidgets('a build Google refuses says so, and offers email', (
    tester,
  ) async {
    final calls = GoogleCalls();
    final app = await openLogin(tester, server(calls));
    app.backend.googleIdentity.nextRefusal = const GoogleSignInRefused(
      GoogleSignInFailure.misconfigured,
    );

    await tapGoogle(tester);
    await app.pumpUntilFound(
      find.textContaining("isn't set up for this build"),
    );

    expect(calls.signIns, isEmpty);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('a token the server will not accept says so', (tester) async {
    final calls = GoogleCalls();
    final app = await openLogin(
      tester,
      server(calls, status: 401, errorCode: 'AUTH_TOKEN_INVALID'),
    );

    await tapGoogle(tester);
    await app.pumpUntilFound(find.textContaining('could not be verified'));

    expect(calls.signIns, hasLength(1));
    expect(await app.backend.tokenStore.read(), isNull);
  });

  testWidgets('a build with no Google settings does not offer it', (
    tester,
  ) async {
    final calls = GoogleCalls();
    final app = await pumpKinvoApp(tester, respond: server(calls));
    app.backend.googleIdentity.available = false;

    await app.pumpUntilFound(find.text('Log In'));
    await tester.tap(find.text('Log In'));
    await app.pumpUntilFound(find.byType(LoginScreen));

    expect(find.text('Continue with Google'), findsNothing);
    // The ways in that do work are still there.
    expect(find.text('Continue with your phone number'), findsOneWidget);
  });
}
