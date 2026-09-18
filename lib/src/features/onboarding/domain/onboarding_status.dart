import 'package:flutter/foundation.dart';

import '../../../core/network/api_envelope.dart';

/// Something the backend requires before an account can use the app.
enum OnboardingRequirement {
  displayName('display_name'),
  dateOfBirth('date_of_birth'),
  bio('bio'),
  photo('photo'),
  interests('interests'),
  mode('mode'),
  location('location');

  const OnboardingRequirement(this.wireValue);

  final String wireValue;

  static OnboardingRequirement? fromWireValue(String value) {
    return values.where((each) => each.wireValue == value).firstOrNull;
  }
}

/// How far the signed-in account is through onboarding, from
/// `GET /onboarding`.
@immutable
final class OnboardingStatus {
  const OnboardingStatus({
    required this.isComplete,
    required this.missing,
    this.unknownMissing = const [],
  });

  factory OnboardingStatus.fromJson(JsonMap json) {
    if (json case {
      'is_complete': final bool isComplete,
      'missing': final List<Object?> missing,
    }) {
      final requirements = readRequirements(missing);
      return OnboardingStatus(
        isComplete: isComplete,
        missing: requirements.known,
        unknownMissing: requirements.unknown,
      );
    }
    throw const FormatException('Expected is_complete and missing.');
  }

  /// Reads a list of requirement names, as `GET /onboarding` sends in
  /// `missing` and an `ONBOARDING_INCOMPLETE` error sends in its details.
  static ({Set<OnboardingRequirement> known, List<String> unknown})
  readRequirements(List<Object?> names) {
    final known = <OnboardingRequirement>{};
    final unknown = <String>[];
    for (final name in names.whereType<String>()) {
      switch (OnboardingRequirement.fromWireValue(name)) {
        case final requirement?:
          known.add(requirement);
        case null:
          unknown.add(name);
      }
    }
    return (known: known, unknown: unknown);
  }

  final bool isComplete;
  final Set<OnboardingRequirement> missing;

  /// Requirements added to the backend after this version of the app, which
  /// it has no way to meet.
  final List<String> unknownMissing;
}
