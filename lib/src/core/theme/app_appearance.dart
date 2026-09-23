import 'package:flutter/material.dart';

import '../../features/settings/domain/user_settings.dart';

/// How the app should look and move for this account.
///
/// Read from the server's settings, so someone who needs larger text or less
/// movement is set up that way on a new phone without doing it again.
@immutable
final class AppAppearance {
  const AppAppearance({
    this.theme = AppThemeChoice.system,
    this.textScale = 1,
    this.reduceMotion = false,
    this.highContrast = false,
  });

  /// What a phone gets before the settings have been read.
  static const standard = AppAppearance();

  final AppThemeChoice theme;

  /// A multiplier on every piece of text in the app.
  final double textScale;

  final bool reduceMotion;
  final bool highContrast;

  ThemeMode get themeMode => switch (theme) {
    AppThemeChoice.system => ThemeMode.system,
    AppThemeChoice.light => ThemeMode.light,
    AppThemeChoice.dark => ThemeMode.dark,
  };

  /// Applies the parts of this that are the phone's business rather than the
  /// theme's: how big text is, and whether things move.
  ///
  /// Text scaling is clamped, not just multiplied: someone whose phone is
  /// already set to large text and who then asks Kinvo for larger again would
  /// otherwise get both, and no screen survives that.
  MediaQueryData applyTo(MediaQueryData media) {
    return media.copyWith(
      textScaler: TextScaler.linear(
        (media.textScaler.scale(1) * textScale).clamp(
          UserSettings.minimumTextScale,
          UserSettings.maximumTextScale,
        ),
      ),
      disableAnimations: media.disableAnimations || reduceMotion,
      highContrast: media.highContrast || highContrast,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppAppearance &&
        other.theme == theme &&
        other.textScale == textScale &&
        other.reduceMotion == reduceMotion &&
        other.highContrast == highContrast;
  }

  @override
  int get hashCode => Object.hash(theme, textScale, reduceMotion, highContrast);
}
