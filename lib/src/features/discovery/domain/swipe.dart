import 'package:flutter/foundation.dart';

import '../../../core/network/api_envelope.dart';

/// What someone can do with a card. The same three in every mode: the mode
/// only changes the words on the buttons, which come from `GET /config`.
enum SwipeAction {
  pass('pass'),
  like('like'),
  superLike('super_like');

  const SwipeAction(this.wireName);

  /// The action's name in the API.
  final String wireName;

  static SwipeAction? fromWireName(String value) {
    for (final action in values) {
      if (action.wireName == value) return action;
    }
    return null;
  }

  /// Whether the action spends today's allowance. A pass never does.
  bool get usesAllowance => this != pass;
}

/// What's left of today's likes after a swipe.
@immutable
final class SwipeAllowance {
  const SwipeAllowance({
    required this.limit,
    required this.used,
    required this.remaining,
  });

  /// A plan without a daily limit.
  static const unlimited = SwipeAllowance(
    limit: null,
    used: 0,
    remaining: null,
  );

  factory SwipeAllowance.fromJson(JsonMap json) {
    if (json case {
      'limit': final int limit,
      'used': final int used,
      'remaining': final int remaining,
      'is_unlimited': final bool isUnlimited,
    }) {
      // The server sends -1 for both numbers when there is no limit.
      if (isUnlimited) return unlimited;
      return SwipeAllowance(limit: limit, used: used, remaining: remaining);
    }
    throw const FormatException(
      'Expected an allowance with limit, used, remaining and is_unlimited.',
    );
  }

  /// The daily limit, or `null` when there is none.
  final int? limit;
  final int used;

  /// Likes left today, or `null` when there is no limit.
  final int? remaining;

  bool get isUnlimited => limit == null;
}

/// A match that a swipe has just made.
@immutable
final class NewMatch {
  const NewMatch({
    required this.id,
    required this.mode,
    required this.isSuperLike,
    required this.matchedAt,
  });

  factory NewMatch.fromJson(JsonMap json) {
    if (json case {
      'id': final String id,
      'mode': final String mode,
      'is_super_like': final bool isSuperLike,
      'matched_at': final String matchedAt,
    } when id.isNotEmpty) {
      if (DateTime.tryParse(matchedAt) case final matched?) {
        return NewMatch(
          id: id,
          mode: mode,
          isSuperLike: isSuperLike,
          matchedAt: matched,
        );
      }
    }
    throw const FormatException(
      'Expected a match with id, mode, is_super_like and matched_at.',
    );
  }

  final String id;
  final String mode;
  final bool isSuperLike;
  final DateTime matchedAt;
}

/// The server's answer to a swipe.
@immutable
final class SwipeResult {
  const SwipeResult({
    required this.action,
    required this.match,
    required this.allowance,
  });

  /// Reads the `data` of `POST /discovery/{mode}/swipe`.
  factory SwipeResult.fromJson(JsonMap json) {
    if (json case {
      'action': final String actionName,
      'is_match': final bool isMatch,
      'match': final JsonMap? match,
      'quota': final JsonMap quota,
    } when isMatch == (match != null)) {
      if (SwipeAction.fromWireName(actionName) case final action?) {
        return SwipeResult(
          action: action,
          match: match == null ? null : NewMatch.fromJson(match),
          allowance: SwipeAllowance.fromJson(quota),
        );
      }
    }
    throw const FormatException(
      'Expected a swipe result with action, a match when is_match is true, '
      'and quota.',
    );
  }

  final SwipeAction action;

  /// The match the swipe made, when it was the second like.
  final NewMatch? match;

  final SwipeAllowance allowance;
}

/// The server's answer to rewinding the last swipe.
@immutable
final class RewindResult {
  const RewindResult({
    required this.restoredUserId,
    required this.action,
    required this.matchRemoved,
  });

  /// Reads the `data` of `POST /discovery/{mode}/rewind`.
  factory RewindResult.fromJson(JsonMap json) {
    if (json case {
      'restored_user_id': final String restoredUserId,
      'action': final String actionName,
      'match_removed': final bool matchRemoved,
    } when restoredUserId.isNotEmpty) {
      if (SwipeAction.fromWireName(actionName) case final action?) {
        return RewindResult(
          restoredUserId: restoredUserId,
          action: action,
          matchRemoved: matchRemoved,
        );
      }
    }
    throw const FormatException(
      'Expected a rewind result with restored_user_id, action and '
      'match_removed.',
    );
  }

  /// The person whose card is back in the deck.
  final String restoredUserId;

  /// What the undone swipe was.
  final SwipeAction action;

  /// Whether undoing it also undid a match.
  final bool matchRemoved;
}
