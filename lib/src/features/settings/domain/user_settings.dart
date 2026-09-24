import 'package:flutter/foundation.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/units/distance.dart';

/// How the app looks, as the account asked for it.
///
/// Kept on the server with everything else, so the way someone needs to
/// read the app follows them to a new phone instead of being set up again.
enum AppThemeChoice {
  system('system'),
  light('light'),
  dark('dark');

  const AppThemeChoice(this.wireValue);

  final String wireValue;

  static AppThemeChoice fromWire(String value) {
    for (final choice in values) {
      if (choice.wireValue == value) return choice;
    }
    // A choice added to the server after this version of the app.
    return system;
  }
}

/// The settings the app uses, from `GET /settings`. They're kept on the
/// server, so they follow the user to a new phone.
@immutable
final class UserSettings {
  const UserSettings({
    required this.distanceUnit,
    required this.showDistance,
    required this.showLastActive,
    this.theme = AppThemeChoice.system,
    this.textScale = 1,
    this.reduceMotion = false,
    this.highContrast = false,
    this.incognito = false,
    this.verifiedOnlyEverywhere = false,
    this.pauseNewMatches = false,
    this.snooze,
  });

  /// What the server accepts, and what the app offers.
  static const minimumTextScale = 0.8;
  static const maximumTextScale = 2.0;

  factory UserSettings.fromJson(JsonMap json) {
    if (json case {
      'distance_unit': final String distanceUnit,
      'show_distance': final bool showDistance,
      'show_last_active': final bool showLastActive,
      'snooze': {
        'is_snoozed': final bool isSnoozed,
        'ends_at': final String? endsAt,
      },
    }) {
      return UserSettings(
        // A unit added to the server later is shown in miles until the app
        // learns it.
        distanceUnit: DistanceUnit.fromWire(distanceUnit) ?? DistanceUnit.miles,
        showDistance: showDistance,
        showLastActive: showLastActive,
        // Appearance is read leniently: an older server that does not send
        // these is not a reason to refuse every setting the user has.
        theme: switch (json['theme']) {
          final String theme => AppThemeChoice.fromWire(theme),
          _ => AppThemeChoice.system,
        },
        textScale: switch (json['text_scale']) {
          final num scale => scale.toDouble().clamp(
            minimumTextScale,
            maximumTextScale,
          ),
          _ => 1.0,
        },
        reduceMotion: json['reduce_motion'] == true,
        highContrast: json['high_contrast'] == true,
        // Off unless the server says on, in as many words: none of these may
        // be switched on by a server too old to know them.
        incognito: json['incognito'] == true,
        verifiedOnlyEverywhere: json['global_verified_only'] == true,
        pauseNewMatches: json['pause_new_matches'] == true,
        snooze: isSnoozed
            ? Snooze(endsAt: endsAt == null ? null : DateTime.tryParse(endsAt))
            : null,
      );
    }
    throw const FormatException(
      'Expected settings with distance_unit, show_distance, show_last_active '
      'and snooze.',
    );
  }

  /// What a new account starts with.
  static const defaults = UserSettings(
    distanceUnit: DistanceUnit.miles,
    showDistance: true,
    showLastActive: true,
  );

  final DistanceUnit distanceUnit;

  /// Light, dark, or whatever the phone is set to.
  final AppThemeChoice theme;

  /// How much bigger or smaller the app sets its text than usual, between
  /// [minimumTextScale] and [maximumTextScale]. 1 is the phone's own size.
  final double textScale;

  /// Whether to keep movement to a minimum, for people who find it
  /// uncomfortable or distracting.
  final bool reduceMotion;

  /// Whether to draw with stronger contrast.
  final bool highContrast;

  /// Whether other people see roughly how far away the user is.
  final bool showDistance;

  /// Whether other people see when the user is online or was last active.
  final bool showLastActive;

  /// Only people the user has liked, and their matches, see them in
  /// Discover.
  final bool incognito;

  /// Discover shows only verified people, in every mode.
  final bool verifiedOnlyEverywhere;

  /// The user stays visible but matches with nobody new. Likes wait until
  /// the pause ends.
  final bool pauseNewMatches;

  /// The break the user is taking, or `null` when they aren't taking one.
  /// On a break, nobody new sees them in Discover.
  final Snooze? snooze;

  bool get isOnBreak => snooze != null;

  UserSettings copyWith({
    DistanceUnit? distanceUnit,
    bool? showDistance,
    bool? showLastActive,
    AppThemeChoice? theme,
    double? textScale,
    bool? reduceMotion,
    bool? highContrast,
    bool? incognito,
    bool? verifiedOnlyEverywhere,
    bool? pauseNewMatches,
    ValueGetter<Snooze?>? snooze,
  }) {
    return UserSettings(
      distanceUnit: distanceUnit ?? this.distanceUnit,
      showDistance: showDistance ?? this.showDistance,
      showLastActive: showLastActive ?? this.showLastActive,
      theme: theme ?? this.theme,
      textScale: textScale ?? this.textScale,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      highContrast: highContrast ?? this.highContrast,
      incognito: incognito ?? this.incognito,
      verifiedOnlyEverywhere:
          verifiedOnlyEverywhere ?? this.verifiedOnlyEverywhere,
      pauseNewMatches: pauseNewMatches ?? this.pauseNewMatches,
      snooze: snooze == null ? this.snooze : snooze(),
    );
  }
}

/// A break from Discover.
@immutable
final class Snooze {
  const Snooze({this.endsAt});

  /// When it ends by itself, or `null` when it lasts until the user comes
  /// back.
  final DateTime? endsAt;
}
