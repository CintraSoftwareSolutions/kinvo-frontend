import 'package:flutter/foundation.dart';

import '../network/api_error_code.dart';
import '../network/api_exception.dart';

/// Why the server stopped an action and offered an upgrade instead.
///
/// Always read from the server's answer, never decided by the app: which
/// features are paid for is data on the server, so moving one between plans
/// needs no app release.
@immutable
sealed class Paywall {
  const Paywall({required this.message, required this.canUpgrade});

  /// The server's explanation, which can be shown as it is.
  final String message;

  /// Whether a higher plan exists. False on the top plan, where offering an
  /// upgrade would lead nowhere.
  final bool canUpgrade;

  /// The paywall that [error] describes, or `null` when it isn't one.
  static Paywall? fromError(Object error) {
    if (error case ApiErrorException(:final code, :final message)) {
      final details = error.details ?? const <String, Object?>{};
      final canUpgrade = details['upgrade_available'] != false;

      return switch (code) {
        ApiErrorCode.quotaExceeded => DailyLimitReached(
          message: message,
          canUpgrade: canUpgrade,
          resetsAt: switch (details['resets_at']) {
            final String value => DateTime.tryParse(value),
            _ => null,
          },
        ),
        ApiErrorCode.premiumRequired => PremiumFeature(
          message: message,
          canUpgrade: canUpgrade,
          feature: switch (details['required_feature']) {
            final String value when value.isNotEmpty => value,
            _ => null,
          },
        ),
        _ => null,
      };
    }
    return null;
  }
}

/// Today's allowance of an action, such as likes, is used up.
final class DailyLimitReached extends Paywall {
  const DailyLimitReached({
    required super.message,
    required super.canUpgrade,
    this.resetsAt,
  });

  /// When the allowance comes back, if the server said.
  final DateTime? resetsAt;
}

/// The action is part of a paid plan, such as rewinding a swipe.
final class PremiumFeature extends Paywall {
  const PremiumFeature({
    required super.message,
    required super.canUpgrade,
    this.feature,
  });

  /// The server's name for what was asked for, such as `rewind`.
  final String? feature;
}
