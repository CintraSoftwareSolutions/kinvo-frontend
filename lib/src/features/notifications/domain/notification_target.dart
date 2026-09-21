import 'package:flutter/foundation.dart';

import 'app_notification.dart';

/// Where opening a notification takes the user.
@immutable
sealed class NotificationTarget {
  const NotificationTarget();

  /// The target for a notification of [category] carrying [data], from the
  /// feed or from a push, whose values arrive as strings.
  static NotificationTarget of(
    NotificationCategory category,
    Map<String, Object?> data,
  ) {
    final conversationId = _text(data, 'conversation_id');
    final matchId = _text(data, 'match_id');
    final planId = _text(data, 'plan_id');

    return switch (category) {
      NotificationCategory.newMessage || NotificationCategory.newMatch
          when conversationId != null =>
        OpenConversation(conversationId),
      NotificationCategory.newMessage ||
      NotificationCategory.newMatch ||
      NotificationCategory.call when matchId != null => OpenMatch(matchId),
      NotificationCategory.newMatch ||
      NotificationCategory.call => const OpenMatches(),
      NotificationCategory.newLike => OpenLikes(_text(data, 'mode')),
      NotificationCategory.planUpdate when planId != null => OpenPlan(planId),
      NotificationCategory.planUpdate => const OpenPlans(),
      NotificationCategory.safety => const OpenSafety(),
      NotificationCategory.newMessage ||
      NotificationCategory.moderation ||
      // Verification results have nowhere of their own to go: the app's
      // verification screen is still a prototype. The notification itself
      // carries the outcome.
      NotificationCategory.verification ||
      NotificationCategory.subscription ||
      NotificationCategory.system ||
      NotificationCategory.unknown => const OpenNotifications(),
    };
  }

  /// A non-empty string value. Push data turns a missing value into the text
  /// "null", which counts as missing too.
  static String? _text(Map<String, Object?> data, String key) {
    return switch (data[key]) {
      final String value when value.isNotEmpty && value != 'null' => value,
      _ => null,
    };
  }
}

final class OpenConversation extends NotificationTarget {
  const OpenConversation(this.conversationId);

  final String conversationId;

  @override
  bool operator ==(Object other) =>
      other is OpenConversation && other.conversationId == conversationId;

  @override
  int get hashCode => Object.hash(OpenConversation, conversationId);
}

/// A match whose conversation has to be looked up first.
final class OpenMatch extends NotificationTarget {
  const OpenMatch(this.matchId);

  final String matchId;

  @override
  bool operator ==(Object other) =>
      other is OpenMatch && other.matchId == matchId;

  @override
  int get hashCode => Object.hash(OpenMatch, matchId);
}

/// The Matches tab.
final class OpenMatches extends NotificationTarget {
  const OpenMatches();

  @override
  bool operator ==(Object other) => other is OpenMatches;

  @override
  int get hashCode => (OpenMatches).hashCode;
}

/// Who liked the user, in [mode] when known.
final class OpenLikes extends NotificationTarget {
  const OpenLikes(this.mode);

  final String? mode;

  @override
  bool operator ==(Object other) => other is OpenLikes && other.mode == mode;

  @override
  int get hashCode => Object.hash(OpenLikes, mode);
}

final class OpenPlan extends NotificationTarget {
  const OpenPlan(this.planId);

  final String planId;

  @override
  bool operator ==(Object other) => other is OpenPlan && other.planId == planId;

  @override
  int get hashCode => Object.hash(OpenPlan, planId);
}

final class OpenPlans extends NotificationTarget {
  const OpenPlans();

  @override
  bool operator ==(Object other) => other is OpenPlans;

  @override
  int get hashCode => (OpenPlans).hashCode;
}

final class OpenSafety extends NotificationTarget {
  const OpenSafety();

  @override
  bool operator ==(Object other) => other is OpenSafety;

  @override
  int get hashCode => (OpenSafety).hashCode;
}

/// The notifications list, for notifications with nowhere more specific to go.
final class OpenNotifications extends NotificationTarget {
  const OpenNotifications();

  @override
  bool operator ==(Object other) => other is OpenNotifications;

  @override
  int get hashCode => (OpenNotifications).hashCode;
}
