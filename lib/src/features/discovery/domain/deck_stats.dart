import 'package:flutter/foundation.dart';

import '../../../core/network/api_envelope.dart';
import 'swipe.dart';

/// A boost that is raising someone's place in other people's decks.
@immutable
final class ActiveBoost {
  const ActiveBoost({
    required this.id,
    required this.mode,
    required this.startedAt,
    required this.endsAt,
  });

  /// Reads a boost, as `POST /discovery/{mode}/boost` and the deck stats send
  /// it.
  factory ActiveBoost.fromJson(JsonMap json) {
    if (json case {
      'id': final String id,
      'mode': final String mode,
      'started_at': final String startedAt,
      'ends_at': final String endsAt,
    } when id.isNotEmpty) {
      final started = DateTime.tryParse(startedAt);
      final ends = DateTime.tryParse(endsAt);
      if (started != null && ends != null) {
        return ActiveBoost(
          id: id,
          mode: mode,
          startedAt: started,
          endsAt: ends,
        );
      }
    }
    throw const FormatException(
      'Expected a boost with id, mode, started_at and ends_at.',
    );
  }

  final String id;
  final String mode;
  final DateTime startedAt;
  final DateTime endsAt;

  bool isActiveAt(DateTime now) => endsAt.isAfter(now);
}

/// Where someone stands with one mode's deck today.
@immutable
final class DeckStats {
  const DeckStats({
    required this.mode,
    required this.liked,
    required this.passed,
    required this.superLiked,
    required this.matches,
    required this.likesReceived,
    required this.cardsRemaining,
    required this.boost,
    required this.allowance,
  });

  /// Reads the `data` of `GET /discovery/{mode}/stats`.
  factory DeckStats.fromJson(JsonMap json) {
    if (json case {
      'mode': final String mode,
      'liked': final int liked,
      'passed': final int passed,
      'super_liked': final int superLiked,
      'matches': final int matches,
      'likes_received': final int likesReceived,
      'cards_remaining': final int cardsRemaining,
      'boost': final JsonMap? boost,
      'swipe_quota': final JsonMap allowance,
    }) {
      return DeckStats(
        mode: mode,
        liked: liked,
        passed: passed,
        superLiked: superLiked,
        matches: matches,
        likesReceived: likesReceived,
        cardsRemaining: cardsRemaining,
        boost: boost == null ? null : ActiveBoost.fromJson(boost),
        allowance: SwipeAllowance.fromJson(allowance),
      );
    }
    throw const FormatException(
      'Expected deck stats with mode, liked, passed, super_liked, matches, '
      'likes_received, cards_remaining, boost and swipe_quota.',
    );
  }

  final String mode;

  /// Swipes made in this mode, ever.
  final int liked;
  final int passed;
  final int superLiked;

  /// Active matches in this mode.
  final int matches;

  /// People waiting in the likes inbox. A count only: who they are is part of
  /// a paid plan.
  final int likesReceived;

  /// Cards left in today's deck.
  final int cardsRemaining;

  /// The boost running in this mode, if there is one.
  final ActiveBoost? boost;

  final SwipeAllowance allowance;
}
