import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/theme/app_theme.dart';
import 'package:kinvo/src/core/theme/kinvo_colors.dart';
import 'package:kinvo/src/core/theme/motion.dart';
import 'package:kinvo/src/core/theme/system_bars.dart';
import 'package:kinvo/src/core/widgets/flow_widgets.dart';

void main() {
  group('the theme', () {
    test('carries the palette it was made from', () {
      for (final brightness in Brightness.values) {
        for (final highContrast in [false, true]) {
          final theme = AppTheme.of(brightness, highContrast: highContrast);

          expect(theme.brightness, brightness);
          expect(theme.colorScheme.brightness, brightness);
          expect(
            theme.extension<KinvoColors>(),
            same(KinvoColors.of(brightness, highContrast: highContrast)),
          );
        }
      }
    });

    test("tells Material's own widgets the palette's colours", () {
      final theme = AppTheme.of(Brightness.dark);
      final colors = KinvoColors.dark;

      expect(theme.scaffoldBackgroundColor, colors.background);
      expect(theme.colorScheme.primary, colors.purple);
      expect(theme.colorScheme.surface, colors.surface);
      expect(theme.colorScheme.onSurface, colors.textPrimary);
      expect(theme.textTheme.bodyMedium?.color, colors.textPrimary);
      expect(theme.dialogTheme.backgroundColor, colors.surface);
      expect(theme.bottomSheetTheme.backgroundColor, colors.surface);
    });

    test('is made once for each palette', () {
      expect(AppTheme.of(Brightness.dark), same(AppTheme.of(Brightness.dark)));
    });
  });

  group('less movement', () {
    testWidgets('stops an animation when the phone asks for it', (
      tester,
    ) async {
      late Duration asked;
      Widget app(bool reduce) => MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Builder(
          builder: (context) {
            asked = context.motion(const Duration(milliseconds: 200));
            return const SizedBox();
          },
        ),
      );

      await tester.pumpWidget(app(false));
      expect(asked, const Duration(milliseconds: 200));

      await tester.pumpWidget(app(true));
      expect(asked, Duration.zero);
    });

    Future<Rect> pushedAfterOneFrame(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.of(Brightness.light),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('Next screen')),
                ),
              ),
              child: const Text('Go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Go'));
      // A pushed screen spends its first frame offstage, while its heroes
      // are measured; the second is the first anyone sees.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      return tester.getRect(find.text('Next screen'));
    }

    testWidgets('lets screens slide in normally', (tester) async {
      final arriving = await pushedAfterOneFrame(tester);
      await tester.pumpAndSettle();

      expect(arriving, isNot(tester.getRect(find.text('Next screen'))));
    });

    testWidgets('makes a screen appear rather than slide in', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      final arriving = await pushedAfterOneFrame(tester);
      await tester.pumpAndSettle();

      expect(arriving, tester.getRect(find.text('Next screen')));
    });
  });

  group("the phone's status bar", () {
    Future<SystemUiOverlayStyle> styleOver(
      WidgetTester tester, {
      required Brightness theme,
      bool overDark = false,
    }) async {
      const content = SizedBox.expand();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.of(theme),
          home: overDark
              ? const SystemBars.overDark(child: content)
              : const SystemBars(child: content),
        ),
      );
      return tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.descendant(
              of: find.byType(SystemBars),
              matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
            ),
          )
          .value;
    }

    testWidgets('has dark icons over the light theme', (tester) async {
      final style = await styleOver(tester, theme: Brightness.light);

      expect(style.statusBarIconBrightness, Brightness.dark);
      expect(style.systemNavigationBarColor, KinvoColors.light.surface);
    });

    testWidgets('has light icons over the dark theme', (tester) async {
      final style = await styleOver(tester, theme: Brightness.dark);

      expect(style.statusBarIconBrightness, Brightness.light);
      expect(style.systemNavigationBarColor, KinvoColors.dark.surface);
    });

    testWidgets('has light icons over a screen that is always dark', (
      tester,
    ) async {
      final style = await styleOver(
        tester,
        theme: Brightness.light,
        overDark: true,
      );

      expect(style.statusBarIconBrightness, Brightness.light);
    });
  });

  testWidgets('an outlined button reads on a light screen', (tester) async {
    // It used to be white unless told otherwise, and three light screens
    // didn't tell it: "Retake", "Check again" and "Answer a prompt" were
    // white on white.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(Brightness.light),
        home: Scaffold(
          body: OutlineActionButton(label: 'Check again', onPressed: () {}),
        ),
      ),
    );

    final style = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(
      style.style?.foregroundColor?.resolve(const {}),
      KinvoColors.light.purple,
    );
  });
}
