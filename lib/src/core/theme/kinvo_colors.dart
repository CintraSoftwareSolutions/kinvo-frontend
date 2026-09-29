import 'package:flutter/material.dart';

/// A hue the app tints things with: a mode's colour, a state such as
/// "confirmed" or "waiting", or the background of an icon.
enum Hue { purple, red, blue, indigo, green, amber, pink, orange, teal }

/// One hue, as it's drawn on the current theme: [color] for icons, dots,
/// badges and borders, [soft] for the pale fill behind them, and [onSoft]
/// for text set on that fill, which needs more contrast than an icon does.
@immutable
final class Tint {
  const Tint({required this.color, required this.soft, required this.onSoft});

  final Color color;
  final Color soft;
  final Color onSoft;

  static Tint lerp(Tint a, Tint b, double t) {
    return Tint(
      color: Color.lerp(a.color, b.color, t)!,
      soft: Color.lerp(a.soft, b.soft, t)!,
      onSoft: Color.lerp(a.onSoft, b.onSoft, t)!,
    );
  }
}

/// What's drawn over a photo, a video, or the brand's gradient: the same in
/// every theme, because what's underneath is.
abstract final class OverlayColors {
  /// Text and icons.
  static const content = Color(0xFFFFFFFF);

  /// Darkens what's underneath, so [content] reads over any photo. Used
  /// with transparency; on its own, the backdrop of a call.
  static const shade = Color(0xFF000000);
}

/// Every colour the app paints with, by what it's for rather than what it
/// looks like, so one screen reads right in light, dark and higher contrast.
/// Read it as `context.colors`.
///
/// Nothing outside `core/theme` names a colour value: a screen that does
/// looks right in one theme and wrong in the others. A test holds that line,
/// and another holds each palette to the contrast its text and controls
/// need.
@immutable
final class KinvoColors extends ThemeExtension<KinvoColors> {
  const KinvoColors({
    required this.brightness,
    required this.highContrast,
    required this.background,
    required this.backgroundGradient,
    required this.surface,
    required this.surfaceSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.onAccent,
    required this.border,
    required this.divider,
    required this.handle,
    required this.shadow,
    required this.purple,
    required this.purpleLight,
    required this.purpleSoft,
    required this.purpleChip,
    required this.green,
    required this.greenSoft,
    required this.success,
    required this.online,
    required this.blue,
    required this.danger,
    required this.dangerSoft,
    required this.dangerStrong,
    required this.welcomeGradient,
    required this.premiumGradient,
    required this.tints,
  });

  final Brightness brightness;

  /// Whether this is one of the higher-contrast palettes.
  final bool highContrast;

  /// Behind a screen's content.
  final Color background;

  /// Behind the signed-out screens and onboarding.
  final Gradient backgroundGradient;

  /// Cards, sheets and dialogs.
  final Color surface;

  /// A quieter fill inside a surface: chips, inputs, rows.
  final Color surfaceSoft;

  final Color textPrimary;
  final Color textSecondary;

  /// Text that matters least: hints, times, counts.
  final Color textMuted;

  /// Text and icons on the accent, or on any other solid colour: a mode's,
  /// a warning's.
  final Color onAccent;

  final Color border;
  final Color divider;

  /// The grab bar at the top of a sheet.
  final Color handle;

  /// Under cards that float.
  final Color shadow;

  /// Kinvo's accent: buttons, links, what's selected.
  final Color purple;
  final Color purpleLight;
  final Color purpleSoft;
  final Color purpleChip;

  /// Text that says something went well.
  final Color green;
  final Color greenSoft;

  /// A button that says yes, such as answering a call.
  final Color success;

  /// The dot on someone who's online now.
  final Color online;
  final Color blue;
  final Color danger;
  final Color dangerSoft;

  /// Danger text set on [dangerSoft].
  final Color dangerStrong;

  /// Behind the welcome and loading screens.
  final Gradient welcomeGradient;

  /// Behind what a paid plan includes.
  final Gradient premiumGradient;

  final Map<Hue, Tint> tints;

  /// [hue] as this palette draws it.
  Tint tint(Hue hue) => tints[hue]!;

  bool get isDark => brightness == Brightness.dark;

  // ---------------------------------------------------------------------------
  // The four palettes.

  static const light = KinvoColors(
    brightness: Brightness.light,
    highContrast: false,
    background: Color(0xFFF8F9FE),
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFF0F0FF), Color(0xFFFDF6F6)],
    ),
    surface: Color(0xFFFFFFFF),
    surfaceSoft: Color(0xFFF5F5F9),
    textPrimary: Color(0xFF0C132A),
    textSecondary: Color(0xFF617086),
    textMuted: Color(0xFF9AA4B2),
    onAccent: Color(0xFFFFFFFF),
    border: Color(0xFFE4EAF2),
    divider: Color(0xFFE8EDF4),
    handle: Color(0xFFE5E7EB),
    shadow: Color(0x0A0C132A),
    purple: Color(0xFF6F47CB),
    purpleLight: Color(0xFFA980F4),
    purpleSoft: Color(0xFFF0E8FF),
    purpleChip: Color(0xFFECE4FF),
    green: Color(0xFF0C8463),
    greenSoft: Color(0xFFDDF4EE),
    success: Color(0xFF15B887),
    online: Color(0xFF22C55E),
    blue: Color(0xFF3B82F6),
    danger: Color(0xFFEF4458),
    dangerSoft: Color(0xFFFFE4E8),
    dangerStrong: Color(0xFFB91C1C),
    welcomeGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF6E47CB), Color(0xFFA87EF6), Color(0xFF7B54D8)],
    ),
    premiumGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF6E47CB), Color(0xFFA87EF6), Color(0xFFF59E0B)],
    ),
    tints: {
      Hue.purple: Tint(
        color: Color(0xFF6F47CB),
        soft: Color(0xFFF0E8FF),
        onSoft: Color(0xFF5B34B5),
      ),
      Hue.red: Tint(
        color: Color(0xFFEF4458),
        soft: Color(0xFFFFE4E8),
        onSoft: Color(0xFFBE123C),
      ),
      Hue.blue: Tint(
        color: Color(0xFF2563EB),
        soft: Color(0xFFDBEAFE),
        onSoft: Color(0xFF1D4ED8),
      ),
      Hue.indigo: Tint(
        color: Color(0xFF6366F1),
        soft: Color(0xFFE0E7FF),
        onSoft: Color(0xFF4338CA),
      ),
      Hue.green: Tint(
        color: Color(0xFF10B981),
        soft: Color(0xFFD1FAE5),
        onSoft: Color(0xFF047857),
      ),
      Hue.amber: Tint(
        color: Color(0xFFF59E0B),
        soft: Color(0xFFFEF3C7),
        onSoft: Color(0xFFB45309),
      ),
      Hue.pink: Tint(
        color: Color(0xFFEC4899),
        soft: Color(0xFFFCE7F0),
        onSoft: Color(0xFFBE185D),
      ),
      Hue.orange: Tint(
        color: Color(0xFFF97316),
        soft: Color(0xFFFFEDD5),
        onSoft: Color(0xFFC2410C),
      ),
      Hue.teal: Tint(
        color: Color(0xFF14B8A6),
        soft: Color(0xFFCCFBF1),
        onSoft: Color(0xFF0F766E),
      ),
    },
  );

  /// Light, for people who asked for higher contrast: black text, secondary
  /// text and outlines a good deal darker, and every hue a shade deeper, so
  /// white reads on it and it reads on white.
  static const lightHighContrast = KinvoColors(
    brightness: Brightness.light,
    highContrast: true,
    background: Color(0xFFF8F9FE),
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFF0F0FF), Color(0xFFFDF6F6)],
    ),
    surface: Color(0xFFFFFFFF),
    surfaceSoft: Color(0xFFF5F5F9),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF3B4556),
    textMuted: Color(0xFF566072),
    onAccent: Color(0xFFFFFFFF),
    border: Color(0xFF8792A1),
    divider: Color(0xFFA7AFBC),
    handle: Color(0xFF8792A1),
    shadow: Color(0x1F0C132A),
    purple: Color(0xFF5530B3),
    purpleLight: Color(0xFF7B54D8),
    purpleSoft: Color(0xFFF0E8FF),
    purpleChip: Color(0xFFECE4FF),
    green: Color(0xFF0A6E52),
    greenSoft: Color(0xFFDDF4EE),
    success: Color(0xFF047857),
    online: Color(0xFF15803D),
    blue: Color(0xFF1D4ED8),
    danger: Color(0xFFC8102E),
    dangerSoft: Color(0xFFFFE4E8),
    dangerStrong: Color(0xFF9B1C1C),
    welcomeGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF5530B3), Color(0xFF6E47CB), Color(0xFF5B34B5)],
    ),
    premiumGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF5530B3), Color(0xFF6E47CB), Color(0xFFB45309)],
    ),
    tints: {
      Hue.purple: Tint(
        color: Color(0xFF5B34B5),
        soft: Color(0xFFF0E8FF),
        onSoft: Color(0xFF442788),
      ),
      Hue.red: Tint(
        color: Color(0xFFBE123C),
        soft: Color(0xFFFFE4E8),
        onSoft: Color(0xFF8F0E2D),
      ),
      Hue.blue: Tint(
        color: Color(0xFF1D4ED8),
        soft: Color(0xFFDBEAFE),
        onSoft: Color(0xFF163BA2),
      ),
      Hue.indigo: Tint(
        color: Color(0xFF4338CA),
        soft: Color(0xFFE0E7FF),
        onSoft: Color(0xFF322A98),
      ),
      Hue.green: Tint(
        color: Color(0xFF047857),
        soft: Color(0xFFD1FAE5),
        onSoft: Color(0xFF035A41),
      ),
      Hue.amber: Tint(
        color: Color(0xFFB45309),
        soft: Color(0xFFFEF3C7),
        onSoft: Color(0xFF873E07),
      ),
      Hue.pink: Tint(
        color: Color(0xFFBE185D),
        soft: Color(0xFFFCE7F0),
        onSoft: Color(0xFF8F1246),
      ),
      Hue.orange: Tint(
        color: Color(0xFFC2410C),
        soft: Color(0xFFFFEDD5),
        onSoft: Color(0xFF923109),
      ),
      Hue.teal: Tint(
        color: Color(0xFF0F766E),
        soft: Color(0xFFCCFBF1),
        onSoft: Color(0xFF0B5953),
      ),
    },
  );

  /// Dark. The hues keep their light-theme colours, which read on the dark
  /// surfaces and carry white text as they do in light; what sits on their
  /// soft fills is lighter instead.
  static const dark = KinvoColors(
    brightness: Brightness.dark,
    highContrast: false,
    background: Color(0xFF0B0E16),
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF12121F), Color(0xFF150F17)],
    ),
    surface: Color(0xFF161A24),
    surfaceSoft: Color(0xFF1F2430),
    textPrimary: Color(0xFFEEF1F7),
    textSecondary: Color(0xFFA4ACBD),
    textMuted: Color(0xFF727B8E),
    onAccent: Color(0xFFFFFFFF),
    border: Color(0xFF2C3242),
    divider: Color(0xFF252B38),
    handle: Color(0xFF3B4253),
    shadow: Color(0x66000000),
    purple: Color(0xFF7B5CE7),
    purpleLight: Color(0xFFB39DFF),
    purpleSoft: Color(0xFF2A2342),
    purpleChip: Color(0xFF30284C),
    green: Color(0xFF34C79B),
    greenSoft: Color(0xFF15302A),
    success: Color(0xFF15B887),
    online: Color(0xFF34D399),
    blue: Color(0xFF3B82F6),
    danger: Color(0xFFEF4458),
    dangerSoft: Color(0xFF3A1A22),
    dangerStrong: Color(0xFFFF97A4),
    welcomeGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF4A2E9E), Color(0xFF6D4FC4), Color(0xFF52369F)],
    ),
    premiumGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF6E47CB), Color(0xFFA87EF6), Color(0xFFF59E0B)],
    ),
    tints: {
      Hue.purple: Tint(
        color: Color(0xFF7B5CE7),
        soft: Color(0xFF2A2342),
        onSoft: Color(0xFFC4B3FF),
      ),
      Hue.red: Tint(
        color: Color(0xFFEF4458),
        soft: Color(0xFF3A1A22),
        onSoft: Color(0xFFFF97A4),
      ),
      Hue.blue: Tint(
        color: Color(0xFF3B82F6),
        soft: Color(0xFF172A45),
        onSoft: Color(0xFF93C5FD),
      ),
      Hue.indigo: Tint(
        color: Color(0xFF6366F1),
        soft: Color(0xFF1F2247),
        onSoft: Color(0xFFA5B4FC),
      ),
      Hue.green: Tint(
        color: Color(0xFF10B981),
        soft: Color(0xFF13302A),
        onSoft: Color(0xFF6EE7B7),
      ),
      Hue.amber: Tint(
        color: Color(0xFFF59E0B),
        soft: Color(0xFF392D12),
        onSoft: Color(0xFFFCD34D),
      ),
      Hue.pink: Tint(
        color: Color(0xFFEC4899),
        soft: Color(0xFF3A1A2F),
        onSoft: Color(0xFFF9A8D4),
      ),
      Hue.orange: Tint(
        color: Color(0xFFF97316),
        soft: Color(0xFF3A2515),
        onSoft: Color(0xFFFDBA74),
      ),
      Hue.teal: Tint(
        color: Color(0xFF14B8A6),
        soft: Color(0xFF12302D),
        onSoft: Color(0xFF5EEAD4),
      ),
    },
  );

  /// Dark, for people who asked for higher contrast: a black background,
  /// white text, outlines that stand out, and every hue deep enough for
  /// white to read on it.
  static const darkHighContrast = KinvoColors(
    brightness: Brightness.dark,
    highContrast: true,
    background: Color(0xFF000000),
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF000000), Color(0xFF000000)],
    ),
    surface: Color(0xFF0E1016),
    surfaceSoft: Color(0xFF1A1D26),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFD6DBE5),
    textMuted: Color(0xFFAEB5C4),
    onAccent: Color(0xFFFFFFFF),
    border: Color(0xFF7D8598),
    divider: Color(0xFF5E6577),
    handle: Color(0xFF7D8598),
    shadow: Color(0x00000000),
    purple: Color(0xFF7B5CE7),
    purpleLight: Color(0xFFB39DFF),
    purpleSoft: Color(0xFF241D3D),
    purpleChip: Color(0xFF2A2247),
    green: Color(0xFF4ADE9F),
    greenSoft: Color(0xFF12302A),
    success: Color(0xFF047857),
    online: Color(0xFF4ADE80),
    blue: Color(0xFF2563EB),
    danger: Color(0xFFE8142D),
    dangerSoft: Color(0xFF3A1A22),
    dangerStrong: Color(0xFFFFB3BD),
    welcomeGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF2E1B78), Color(0xFF4A2E9E), Color(0xFF35207F)],
    ),
    premiumGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF5530B3), Color(0xFF6E47CB), Color(0xFFB45309)],
    ),
    tints: {
      Hue.purple: Tint(
        color: Color(0xFF7B5CE7),
        soft: Color(0xFF241D3D),
        onSoft: Color(0xFFD9CCFF),
      ),
      Hue.red: Tint(
        color: Color(0xFFE8142D),
        soft: Color(0xFF3A1A22),
        onSoft: Color(0xFFFFB3BD),
      ),
      Hue.blue: Tint(
        color: Color(0xFF2563EB),
        soft: Color(0xFF172A45),
        onSoft: Color(0xFFBFDBFE),
      ),
      Hue.indigo: Tint(
        color: Color(0xFF5148E5),
        soft: Color(0xFF1F2247),
        onSoft: Color(0xFFC7D2FE),
      ),
      Hue.green: Tint(
        color: Color(0xFF047857),
        soft: Color(0xFF13302A),
        onSoft: Color(0xFFA7F3D0),
      ),
      Hue.amber: Tint(
        color: Color(0xFFB45309),
        soft: Color(0xFF392D12),
        onSoft: Color(0xFFFDE68A),
      ),
      Hue.pink: Tint(
        color: Color(0xFFBE185D),
        soft: Color(0xFF3A1A2F),
        onSoft: Color(0xFFFBCFE8),
      ),
      Hue.orange: Tint(
        color: Color(0xFFC2410C),
        soft: Color(0xFF3A2515),
        onSoft: Color(0xFFFED7AA),
      ),
      Hue.teal: Tint(
        color: Color(0xFF0F766E),
        soft: Color(0xFF12302D),
        onSoft: Color(0xFF99F6E4),
      ),
    },
  );

  /// The palette for [brightness], in higher contrast when asked for.
  static KinvoColors of(Brightness brightness, {bool highContrast = false}) {
    return switch ((brightness, highContrast)) {
      (Brightness.light, false) => light,
      (Brightness.light, true) => lightHighContrast,
      (Brightness.dark, false) => dark,
      (Brightness.dark, true) => darkHighContrast,
    };
  }

  // ---------------------------------------------------------------------------

  @override
  KinvoColors copyWith({
    Brightness? brightness,
    bool? highContrast,
    Color? background,
    Gradient? backgroundGradient,
    Color? surface,
    Color? surfaceSoft,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? onAccent,
    Color? border,
    Color? divider,
    Color? handle,
    Color? shadow,
    Color? purple,
    Color? purpleLight,
    Color? purpleSoft,
    Color? purpleChip,
    Color? green,
    Color? greenSoft,
    Color? success,
    Color? online,
    Color? blue,
    Color? danger,
    Color? dangerSoft,
    Color? dangerStrong,
    Gradient? welcomeGradient,
    Gradient? premiumGradient,
    Map<Hue, Tint>? tints,
  }) {
    return KinvoColors(
      brightness: brightness ?? this.brightness,
      highContrast: highContrast ?? this.highContrast,
      background: background ?? this.background,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      surface: surface ?? this.surface,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      onAccent: onAccent ?? this.onAccent,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      handle: handle ?? this.handle,
      shadow: shadow ?? this.shadow,
      purple: purple ?? this.purple,
      purpleLight: purpleLight ?? this.purpleLight,
      purpleSoft: purpleSoft ?? this.purpleSoft,
      purpleChip: purpleChip ?? this.purpleChip,
      green: green ?? this.green,
      greenSoft: greenSoft ?? this.greenSoft,
      success: success ?? this.success,
      online: online ?? this.online,
      blue: blue ?? this.blue,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      dangerStrong: dangerStrong ?? this.dangerStrong,
      welcomeGradient: welcomeGradient ?? this.welcomeGradient,
      premiumGradient: premiumGradient ?? this.premiumGradient,
      tints: tints ?? this.tints,
    );
  }

  /// Blends two palettes, for the moment the app changes between them.
  @override
  KinvoColors lerp(covariant KinvoColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    Gradient g(Gradient a, Gradient b) => Gradient.lerp(a, b, t)!;
    return KinvoColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      highContrast: t < 0.5 ? highContrast : other.highContrast,
      background: c(background, other.background),
      backgroundGradient: g(backgroundGradient, other.backgroundGradient),
      surface: c(surface, other.surface),
      surfaceSoft: c(surfaceSoft, other.surfaceSoft),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textMuted: c(textMuted, other.textMuted),
      onAccent: c(onAccent, other.onAccent),
      border: c(border, other.border),
      divider: c(divider, other.divider),
      handle: c(handle, other.handle),
      shadow: c(shadow, other.shadow),
      purple: c(purple, other.purple),
      purpleLight: c(purpleLight, other.purpleLight),
      purpleSoft: c(purpleSoft, other.purpleSoft),
      purpleChip: c(purpleChip, other.purpleChip),
      green: c(green, other.green),
      greenSoft: c(greenSoft, other.greenSoft),
      success: c(success, other.success),
      online: c(online, other.online),
      blue: c(blue, other.blue),
      danger: c(danger, other.danger),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      dangerStrong: c(dangerStrong, other.dangerStrong),
      welcomeGradient: g(welcomeGradient, other.welcomeGradient),
      premiumGradient: g(premiumGradient, other.premiumGradient),
      tints: {
        for (final hue in Hue.values)
          hue: Tint.lerp(tint(hue), other.tint(hue), t),
      },
    );
  }
}

/// The app's colours for wherever [BuildContext] is.
extension KinvoColorsOf on BuildContext {
  KinvoColors get colors {
    return Theme.of(this).extension<KinvoColors>() ?? KinvoColors.light;
  }
}
