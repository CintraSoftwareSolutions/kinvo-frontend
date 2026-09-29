import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/core/theme/kinvo_colors.dart';
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

  /// The palette in force on the screen, as any widget would read it.
  KinvoColors paletteOnScreen(WidgetTester tester) =>
      tester.element(find.byType(ThemeScreen)).colors;

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

  testWidgets('higher contrast is saved and paints the app in it', (
    tester,
  ) async {
    await openAppearance(tester);
    expect(paletteOnScreen(tester).highContrast, isFalse);

    await tester.tap(settingsSwitch('Higher contrast'));
    await tester.pumpAndSettle();

    expect(server.highContrast, isTrue);
    final colors = paletteOnScreen(tester);
    expect(colors.highContrast, isTrue);
    expect(colors.textSecondary, KinvoColors.lightHighContrast.textSecondary);
    // And passed on, for anything that asks the phone rather than the theme.
    expect(
      MediaQuery.of(tester.element(find.byType(ThemeScreen))).highContrast,
      isTrue,
    );
  });

  testWidgets('choosing dark saves the choice and paints the app dark', (
    tester,
  ) async {
    final app = await openAppearance(tester);
    expect(paletteOnScreen(tester).isDark, isFalse);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(server.theme, 'dark');
    final saved = app.backend.requestsTo('/settings').last;
    expect((saved.data! as Map<String, Object?>)['theme'], 'dark');

    final screen = tester.element(find.byType(ThemeScreen));
    expect(Theme.of(screen).brightness, Brightness.dark);
    expect(paletteOnScreen(tester).background, KinvoColors.dark.background);
    // Nothing is left saying the app is only painted light.
    expect(find.textContaining('only painted light'), findsNothing);
  });

  testWidgets('dark is there on the next launch', (tester) async {
    server.theme = 'dark';
    await openAppearance(tester);

    expect(paletteOnScreen(tester).isDark, isTrue);
  });

  testWidgets('dark with higher contrast has its own palette', (tester) async {
    server
      ..theme = 'dark'
      ..highContrast = true;
    await openAppearance(tester);

    final colors = paletteOnScreen(tester);
    expect(colors.isDark, isTrue);
    expect(colors.highContrast, isTrue);
    expect(colors.background, KinvoColors.darkHighContrast.background);
  });

  testWidgets("matching the phone follows the phone's dark setting", (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await openAppearance(tester);
    expect(paletteOnScreen(tester).isDark, isTrue);

    // A choice of light holds whatever the phone says.
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(paletteOnScreen(tester).isDark, isFalse);
  });

  testWidgets("the phone's own higher contrast is followed too", (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(highContrast: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await openAppearance(tester);

    expect(server.highContrast, isFalse);
    expect(paletteOnScreen(tester).highContrast, isTrue);
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
