import 'package:flutter/material.dart';

import 'kinvo_colors.dart';

/// The app looks like this.
///
/// Inter ships with the app rather than being fetched at runtime. A font
/// downloaded while the app starts means the first screen anyone sees is
/// set in whatever the phone had to hand, and on a slow or absent
/// connection it stays that way — the one screen where the app should look
/// most like itself.
abstract final class AppTheme {
  /// The bundled family. Declared in `pubspec.yaml` with a file per weight.
  static const fontFamily = 'Inter';

  /// The theme for [brightness], in higher contrast when [highContrast].
  ///
  /// Each of the four is made once: the app asks for them whenever its root
  /// rebuilds, and a theme is not cheap to make.
  static ThemeData of(Brightness brightness, {bool highContrast = false}) {
    return switch ((brightness, highContrast)) {
      (Brightness.light, false) => _light,
      (Brightness.light, true) => _lightHighContrast,
      (Brightness.dark, false) => _dark,
      (Brightness.dark, true) => _darkHighContrast,
    };
  }

  static final _light = _build(KinvoColors.light);
  static final _lightHighContrast = _build(KinvoColors.lightHighContrast);
  static final _dark = _build(KinvoColors.dark);
  static final _darkHighContrast = _build(KinvoColors.darkHighContrast);

  static ThemeData _build(KinvoColors colors) {
    // Material's own widgets — dialogs, switches, date pickers, snack bars —
    // read these roles, so they follow the palette without being told.
    final scheme = ColorScheme(
      brightness: colors.brightness,
      primary: colors.purple,
      onPrimary: colors.onAccent,
      primaryContainer: colors.purpleSoft,
      onPrimaryContainer: colors.tint(Hue.purple).onSoft,
      secondary: colors.purple,
      onSecondary: colors.onAccent,
      secondaryContainer: colors.purpleChip,
      onSecondaryContainer: colors.tint(Hue.purple).onSoft,
      tertiary: colors.green,
      onTertiary: colors.onAccent,
      error: colors.danger,
      onError: colors.onAccent,
      errorContainer: colors.dangerSoft,
      onErrorContainer: colors.dangerStrong,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      onSurfaceVariant: colors.textSecondary,
      surfaceDim: colors.background,
      surfaceBright: colors.surface,
      surfaceContainerLowest: colors.surface,
      surfaceContainerLow: colors.surface,
      surfaceContainer: colors.surface,
      surfaceContainerHigh: colors.surface,
      surfaceContainerHighest: colors.surfaceSoft,
      // What a control is drawn with when it's off: a switch's track, a
      // radio's ring. Strong enough to read as a control, which a card's
      // hairline border isn't.
      outline: colors.textSecondary,
      outlineVariant: colors.divider,
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
      inverseSurface: colors.textPrimary,
      onInverseSurface: colors.surface,
      inversePrimary: colors.purpleLight,
      // Material 3 tints raised surfaces with the accent; Kinvo's cards and
      // sheets are the surface colour, raised or not.
      surfaceTint: const Color(0x00000000),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: colors.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      dividerColor: colors.divider,
      extensions: [colors],
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final MapEntry(key: platform, value: builder)
              in const PageTransitionsTheme().builders.entries)
            platform: _MotionAwareTransitions(builder),
        },
      ),
      dialogTheme: DialogThemeData(backgroundColor: colors.surface),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        modalBackgroundColor: colors.surface,
        dragHandleColor: colors.handle,
      ),
      dividerTheme: DividerThemeData(color: colors.divider),
      iconTheme: IconThemeData(color: colors.textPrimary),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.purple),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.purple,
        selectionColor: colors.purple.withValues(alpha: 0.3),
        selectionHandleColor: colors.purple,
      ),
    );

    final textTheme = base.textTheme.apply(
      fontFamily: fontFamily,
      bodyColor: colors.textPrimary,
      displayColor: colors.textPrimary,
    );

    return base.copyWith(
      // Everything that paints text without reading the text theme, such
      // as a TextStyle written inline on a screen.
      typography: base.typography.copyWith(
        black: base.typography.black.apply(fontFamily: fontFamily),
        white: base.typography.white.apply(fontFamily: fontFamily),
      ),
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -1.4,
        ),
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -1.1,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: colors.textSecondary,
          height: 1.6,
        ),
      ),
    );
  }
}

/// The platform's usual way of moving between screens, except that for
/// people who asked for less movement — on their phone, or in Kinvo — the
/// next screen simply appears.
///
/// Decided when a screen opens rather than when the theme is made, so it
/// follows the phone's setting as well as the app's.
final class _MotionAwareTransitions extends PageTransitionsBuilder {
  const _MotionAwareTransitions(this._standard);

  final PageTransitionsBuilder _standard;

  @override
  Duration get transitionDuration => _standard.transitionDuration;

  @override
  Duration get reverseTransitionDuration => _standard.reverseTransitionDuration;

  /// How the screen underneath moves as the next one arrives.
  @override
  DelegatedTransitionBuilder? get delegatedTransition {
    final standard = _standard.delegatedTransition;
    if (standard == null) return null;
    return (context, animation, secondaryAnimation, allowSnapshotting, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      return standard(
        context,
        animation,
        secondaryAnimation,
        allowSnapshotting,
        child,
      );
    };
  }

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return _standard.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
