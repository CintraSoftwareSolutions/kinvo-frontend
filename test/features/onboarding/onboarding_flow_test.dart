import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/location/location_service.dart';
import 'package:kinvo/src/core/widgets/flow_widgets.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_kinvo_server.dart';

Future<AppHarness> _openOnboarding(
  WidgetTester tester,
  FakeKinvoServer server,
) {
  return pumpKinvoApp(
    tester,
    savedSession: liveSession(),
    respond: server.respond,
  );
}

/// Taps [target] and waits for [next] to appear, then for the step it came
/// from to finish animating away.
Future<void> _tapAndWait(
  WidgetTester tester,
  AppHarness app,
  Finder target,
  Finder next,
) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await app.pumpUntilFound(next);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('a new account sets up its profile and arrives in the app', (
    tester,
  ) async {
    final server = FakeKinvoServer();
    final app = await _openOnboarding(tester, server);
    await app.pumpUntilFound(find.text('About you'));
    expect(find.text('Step 1 of 5'), findsOneWidget);
    // Accounts made by email already have one.
    expect(find.text('DATE OF BIRTH'), findsNothing);

    await tester.enterText(
      find.widgetWithText(AppInputCard, 'BIO'),
      'I like long walks.',
    );
    await _tapAndWait(
      tester,
      app,
      find.text('Continue'),
      find.text('Add your photos'),
    );

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from your photos'));
    await app.pumpUntilFound(find.text('Main'));
    await _tapAndWait(
      tester,
      app,
      find.text('Continue'),
      find.text('Your interests'),
    );

    await tester.tap(find.text('Music'));
    await tester.pump();
    expect(find.text('1 of 10 chosen'), findsOneWidget);
    await _tapAndWait(
      tester,
      app,
      find.text('Continue'),
      find.text("What you're here for"),
    );

    await tester.tap(find.text('Dating'));
    await tester.pump();
    await _tapAndWait(
      tester,
      app,
      find.text('Continue'),
      find.text('Find people near you'),
    );

    await _tapAndWait(
      tester,
      app,
      find.text('Share my location'),
      find.text('Location added'),
    );
    expect(find.text('Leeds, GB'), findsOneWidget);

    await tester.ensureVisible(find.text('Finish setup'));
    await tester.tap(find.text('Finish setup'));
    await app.pumpUntilFound(find.byType(DiscoverScreen));
    await app.pumpUntilLoaded();

    expect(server.isOnboarded, isTrue);
    expect(server.bio, 'I like long walks.');
    expect(server.photos, hasLength(1));
    expect(server.interests, ['music']);
    expect(server.enabledModes, ['dating']);
    expect(server.city, 'Leeds');
  });

  testWidgets('picks up where the user left off, and can go back', (
    tester,
  ) async {
    final server = FakeKinvoServer()
      ..completeProfile(except: {'interests', 'mode', 'location'});
    final app = await _openOnboarding(tester, server);

    await app.pumpUntilFound(find.text('Your interests'));
    expect(find.text('Step 3 of 5'), findsOneWidget);

    await _tapAndWait(
      tester,
      app,
      find.byType(AppBackButton),
      find.text('Add your photos'),
    );
    expect(find.text('Main'), findsOneWidget);
  });

  testWidgets('asks for a photo before moving on', (tester) async {
    final server = FakeKinvoServer()..bio = 'Hello.';
    final app = await _openOnboarding(tester, server);
    await app.pumpUntilFound(find.text('Add your photos'));

    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text('Add at least one photo of yourself.'), findsOneWidget);
    expect(find.text('Add your photos'), findsOneWidget);
  });

  testWidgets('shows which modes need a verified identity', (tester) async {
    final server = FakeKinvoServer()
      ..completeProfile(except: {'mode', 'location'});
    final app = await _openOnboarding(tester, server);
    await app.pumpUntilFound(find.text("What you're here for"));

    expect(
      find.text('Verify your identity to unlock this mode.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Cuddle'));
    await tester.tap(find.text('Cuddle'));
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text('Choose at least one mode.'), findsOneWidget);
    expect(server.enabledModes, isEmpty);
  });

  testWidgets('sends someone who blocked location to the settings', (
    tester,
  ) async {
    final server = FakeKinvoServer()..completeProfile(except: {'location'});
    final app = await _openOnboarding(tester, server);
    await app.pumpUntilFound(find.text('Find people near you'));
    app.backend.locationService.result = const LocationPermissionDenied(
      canAskAgain: false,
    );

    await _tapAndWait(
      tester,
      app,
      find.text('Share my location'),
      find.text('Open Settings'),
    );
    await tester.tap(find.text('Open Settings'));
    await tester.pump();

    expect(app.backend.locationService.appSettingsOpened, 1);
    expect(find.text('Finish setup'), findsNothing);
  });

  testWidgets('offers to try again when onboarding cannot load', (
    tester,
  ) async {
    var offline = true;
    final server = FakeKinvoServer()
      ..intercept = (options) async {
        if (offline && options.uri.path.endsWith('/onboarding')) {
          throw const SocketException('Network is unreachable');
        }
        return null;
      };
    final app = await _openOnboarding(tester, server);

    await app.pumpUntilFound(find.text("We couldn't load your profile"));
    expect(find.textContaining('Check your internet'), findsOneWidget);

    offline = false;
    await tester.tap(find.text('Try again'));
    await app.pumpUntilFound(find.text('About you'));
  });

  testWidgets('asks an account without a date of birth for one', (
    tester,
  ) async {
    final server = FakeKinvoServer()..dateOfBirth = null;
    final app = await _openOnboarding(tester, server);

    await app.pumpUntilFound(find.text('About you'));

    expect(find.text('DATE OF BIRTH'), findsOneWidget);
    expect(find.text('Select your date of birth'), findsOneWidget);
  });
}
