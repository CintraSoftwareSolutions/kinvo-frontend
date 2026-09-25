import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';
import 'package:kinvo/src/features/more/presentation/screens/theme_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_kinvo_server.dart';

/// How the app looks and moves (spec §7 Batch 5): kept on the server, so it
/// follows the account rather than the phone.
void main() {
  late FakeKinvoServer server;

  setUp(() {
    server = FakeKinvoServer()
      ..completeProfile()
      ..isOnboarded = true;
  });

  Future<AppHarness> openAppearance(WidgetTester tester) async {
    final app = await pumpKinvoApp(
      tester,
      savedSession: liveSession(),
      respond: server.respond,
      clock: server.now,
    );
    await app.pumpUntilFound(find.byType(DiscoverScreen));
    await app.pumpUntilLoaded();
    app.router.go(AppRoutes.theme);
    await app.pumpUntilFound(find.byType(ThemeScreen));
    // The More screen underneath loads the profile and the plan; a test that
    // ends with those in flight leaves timers behind.
    await app.pumpUntilLoaded();
    return app;
  }

  /// The text scale in force on the screen, as any widget would read it.
  double scaleOnScreen(WidgetTester tester) {
    final context = tester.element(find.byType(ThemeScreen));
    return MediaQuery.textScalerOf(context).scale(1);
  }

  Finder settingsSwitch(String label) =>
      find.widgetWithText(SwitchListTile, label);

  testWidgets('a larger text size is saved and applies at once', (
    tester,
  ) async {
    final app = await openAppearance(tester);
    expect(scaleOnScreen(tester), 1);

    // Dragged to the far end of the slider.
    final slider = find.byType(Slider);
    await tester.drag(slider, const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(server.textScale, 2.0);
    expect(scaleOnScreen(tester), 2.0);

    final saved = app.backend.requestsTo('/settings').last;
    expect((saved.data! as Map<String, Object?>)['text_scale'], 2.0);
  });

  testWidgets('the size chosen is there on the next launch', (tester) async {
    server.textScale = 1.4;
    await openAppearance(tester);

    expect(scaleOnScreen(tester), closeTo(1.4, 0.001));
  });

  testWidgets('reducing movement is saved and stops the animations', (
    tester,
  ) async {
    final app = await openAppearance(tester);
    final context = tester.element(find.byType(ThemeScreen));
    expect(MediaQuery.disableAnimationsOf(context), isFalse);

    await tester.tap(settingsSwitch('Reduce movement'));
    await tester.pumpAndSettle();

    expect(server.reduceMotion, isTrue);
    expect(
      MediaQuery.disableAnimationsOf(tester.element(find.byType(ThemeScreen))),
      isTrue,
    );
    final saved = app.backend.requestsTo('/settings').last;
    expect((saved.data! as Map<String, Object?>)['reduce_motion'], true);
  });

  testWidgets('higher contrast is saved and passed on to the phone', (
    tester,
  ) async {
    await openAppearance(tester);

    await tester.tap(settingsSwitch('Higher contrast'));
    await tester.pumpAndSettle();

    expect(server.highContrast, isTrue);
    expect(
      MediaQuery.of(tester.element(find.byType(ThemeScreen))).highContrast,
      isTrue,
    );
  });

  testWidgets('choosing dark saves the choice, and says what it does', (
    tester,
  ) async {
    final app = await openAppearance(tester);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(server.theme, 'dark');
    final saved = app.backend.requestsTo('/settings').last;
    expect((saved.data! as Map<String, Object?>)['theme'], 'dark');

    // The app is only painted light so far, and the screen says so rather
    // than leaving someone to wonder why nothing changed.
    expect(find.textContaining('only painted light'), findsOneWidget);
  });

  testWidgets('a refused change goes back and says why', (tester) async {
    final app = await openAppearance(tester);
    server.intercept = (options) async {
      if (options.method == 'PATCH' && options.path.endsWith('/settings')) {
        return jsonResponse(
          500,
          errorEnvelope('INTERNAL_ERROR', 'Could not save that just now.'),
        );
      }
      return null;
    };

    await tester.tap(settingsSwitch('Reduce movement'));
    await app.pumpUntilFound(find.text('Could not save that just now.'));

    // Put back the way it was, rather than showing a setting that is not real.
    final row = tester.widget<SwitchListTile>(
      settingsSwitch('Reduce movement'),
    );
    expect(row.value, isFalse);
    expect(server.reduceMotion, isFalse);
  });

  testWidgets('the welcome screen asks the server for nothing', (tester) async {
    final app = await pumpKinvoApp(tester, respond: server.respond);
    await app.pumpUntilFound(find.text('Log In'));

    // Reading the text size must not become a request with no session behind
    // it.
    expect(app.backend.requestsTo('/settings'), isEmpty);
  });
}
