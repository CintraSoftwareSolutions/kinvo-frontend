import 'package:flutter/foundation.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/units/distance.dart';

/// The settings the app uses, from `GET /settings`. They're kept on the
/// server, so they follow the user to a new phone.
@immutable
final class UserSettings {
  const UserSettings({
    required this.distanceUnit,
    required this.showDistance,
    required this.showLastActive,
    this.snooze,
  });

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

  /// Whether other people see roughly how far away the user is.
  final bool showDistance;

  /// Whether other people see when the user is online or was last active.
  final bool showLastActive;

  /// The break the user is taking, or `null` when they aren't taking one.
  /// On a break, nobody new sees them in Discover.
  final Snooze? snooze;

  bool get isOnBreak => snooze != null;

  UserSettings copyWith({
    DistanceUnit? distanceUnit,
    bool? showDistance,
    bool? showLastActive,
  }) {
    return UserSettings(
      distanceUnit: distanceUnit ?? this.distanceUnit,
      showDistance: showDistance ?? this.showDistance,
      showLastActive: showLastActive ?? this.showLastActive,
      snooze: snooze,
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
