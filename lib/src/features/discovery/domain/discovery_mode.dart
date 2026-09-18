import 'package:flutter/foundation.dart';

import '../../modes/domain/mode_filters.dart';

/// A mode the signed-in user has switched on, as Discover needs it: what to
/// call it and its buttons, and who its deck is built from.
@immutable
final class DiscoveryMode {
  const DiscoveryMode({
    required this.value,
    required this.label,
    required this.likeLabel,
    required this.superLikeLabel,
    required this.isPrimary,
    required this.filters,
  });

  /// The mode's name in the API, for example `study_buddy`.
  final String value;
  final String label;

  /// The word on the like button in this mode, such as "Connect".
  final String likeLabel;

  /// The word for a super like in this mode, such as "Intro".
  final String superLikeLabel;

  /// The mode the app opens in.
  final bool isPrimary;

  final ModeFilters filters;

  DiscoveryMode withFilters(ModeFilters filters) {
    return DiscoveryMode(
      value: value,
      label: label,
      likeLabel: likeLabel,
      superLikeLabel: superLikeLabel,
      isPrimary: isPrimary,
      filters: filters,
    );
  }
}
