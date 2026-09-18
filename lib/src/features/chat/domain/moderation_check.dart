import 'package:flutter/foundation.dart';

import '../../../core/network/api_envelope.dart';

/// What the server's moderation made of a message before it was sent.
///
/// Advice only. The server never refuses to send a message over it, and
/// checks everything sent regardless of what the app does.
@immutable
final class ModerationCheck {
  const ModerationCheck({required this.shouldWarn, required this.warnings});

  /// Reads `POST /moderation/check`.
  factory ModerationCheck.fromJson(JsonMap json) {
    if (json case {
      'should_warn': final bool shouldWarn,
      'findings': final List<Object?> findings,
    }) {
      return ModerationCheck(
        shouldWarn: shouldWarn,
        warnings: [
          for (final finding in findings)
            if (finding case {
              'message': final String message,
            } when message.trim().isNotEmpty)
              message,
        ],
      );
    }
    throw const FormatException('Expected should_warn and findings.');
  }

  /// Nothing worth a warning.
  static const clear = ModerationCheck(shouldWarn: false, warnings: []);

  /// Whether to ask the user to look again before sending.
  final bool shouldWarn;

  /// What was found, in words for the user. They never quote the message.
  final List<String> warnings;
}
