import 'package:flutter/foundation.dart';

import '../../../core/network/api_envelope.dart';

/// Who a mode's deck is built from. Kept per mode, so a small radius for
/// Cuddle and a wide one for Networking can live side by side.
@immutable
final class ModeFilters {
  const ModeFilters({
    required this.minAge,
    required this.maxAge,
    required this.radiusMetres,
    required this.verifiedOnly,
  });

  /// Nobody under 18 is on Kinvo.
  static const youngestAge = 18;

  /// The oldest age the filter offers. The server accepts up to 120, but a
  /// range ending here reads as "no upper limit" to people using it.
  static const oldestAge = 99;

  /// The widest radius the server accepts, in metres.
  static const maxRadiusMetres = 500000;

  /// Reads the filters from a mode, as `GET /modes` and `PATCH /modes/{mode}`
  /// send it.
  static ModeFilters? tryFromJson(JsonMap json) {
    if (json case {
      'min_age': final int minAge,
      'max_age': final int maxAge,
      'radius_metres': final int radiusMetres,
      'verified_only': final bool verifiedOnly,
    } when minAge <= maxAge && radiusMetres > 0) {
      return ModeFilters(
        minAge: minAge,
        maxAge: maxAge,
        radiusMetres: radiusMetres,
        verifiedOnly: verifiedOnly,
      );
    }
    return null;
  }

  final int minAge;
  final int maxAge;
  final int radiusMetres;

  /// Only show people who have verified who they are.
  final bool verifiedOnly;

  /// The body of `PATCH /modes/{mode}` that saves these filters.
  JsonMap toJson() {
    return {
      'min_age': minAge,
      'max_age': maxAge,
      'radius_metres': radiusMetres,
      'verified_only': verifiedOnly,
    };
  }

  ModeFilters copyWith({
    int? minAge,
    int? maxAge,
    int? radiusMetres,
    bool? verifiedOnly,
  }) {
    return ModeFilters(
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      radiusMetres: radiusMetres ?? this.radiusMetres,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ModeFilters &&
        other.minAge == minAge &&
        other.maxAge == maxAge &&
        other.radiusMetres == radiusMetres &&
        other.verifiedOnly == verifiedOnly;
  }

  @override
  int get hashCode => Object.hash(minAge, maxAge, radiusMetres, verifiedOnly);
}
