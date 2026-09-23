import 'package:flutter/material.dart';

import 'app_colors.dart';

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
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.canvas,
      colorScheme: const ColorScheme.light(
        primary: AppColors.purple,
        surface: AppColors.surface,
      ),
    );

    final textTheme = base.textTheme.apply(
      fontFamily: fontFamily,
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
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
          color: AppColors.textSecondary,
          height: 1.6,
        ),
      ),
    );
  }
}
