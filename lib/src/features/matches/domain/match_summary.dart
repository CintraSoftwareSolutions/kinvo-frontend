import 'package:flutter/foundation.dart';

import '../../../core/network/api_envelope.dart';
import '../../profile/domain/user_summary.dart';

/// A match, as the Matches tab lists it.
@immutable
final class MatchSummary {
  const MatchSummary({
    required this.id,
    required this.mode,
    required this.isSuperLike,
    required this.matchedAt,
    required this.expiresAt,
    required this.isExpired,
    required this.extensionCount,
    required this.isWritable,
    required this.user,
    required this.conversationId,
    required this.lastMessageAt,
    required this.lastMessagePreview,
    required this.unreadCount,
  });

  /// Reads one match, as `GET /matches` lists them and
  /// `POST /matches/{id}/extend` returns one.
  factory MatchSummary.fromJson(JsonMap json) {
    if (json case {
      'id': final String id,
      'mode': final String mode,
      'is_super_like': final bool isSuperLike,
      'matched_at': final String matchedAt,
      'expires_at': final String expiresAt,
      'is_expired': final bool isExpired,
      'extension_count': final int extensionCount,
      'is_writable': final bool isWritable,
      'user': final JsonMap user,
      'conversation_id': final String? conversationId,
      'last_message_at': final String? lastMessageAt,
      'last_message_preview': final String? lastMessagePreview,
      'unread_count': final int unreadCount,
    } when id.isNotEmpty) {
      final matched = DateTime.tryParse(matchedAt);
      final expires = DateTime.tryParse(expiresAt);
      if (matched != null && expires != null) {
        return MatchSummary(
          id: id,
          mode: mode,
          isSuperLike: isSuperLike,
          matchedAt: matched,
          expiresAt: expires,
          isExpired: isExpired,
          extensionCount: extensionCount,
          isWritable: isWritable,
          user: UserSummary.fromJson(user),
          conversationId: conversationId,
          lastMessageAt: lastMessageAt == null
              ? null
              : DateTime.tryParse(lastMessageAt),
          lastMessagePreview: lastMessagePreview,
          unreadCount: unreadCount,
        );
      }
    }
    throw const FormatException(
      'Expected a match with id, mode, is_super_like, matched_at, expires_at, '
      'is_expired, extension_count, is_writable, user, conversation_id, '
      'last_message_at, last_message_preview and unread_count.',
    );
  }

  final String id;

  /// The mode it was made in. A match belongs to exactly one.
  final String mode;

  final bool isSuperLike;
  final DateTime matchedAt;

  /// When the match lapses unless someone extends it.
  final DateTime expiresAt;

  /// Decided by the server, so the app never works expiry out from clocks
  /// that disagree.
  final bool isExpired;

  final int extensionCount;

  /// False when the pair can no longer reach each other: expired, unmatched,
  /// or blocked. The server doesn't say which, on purpose.
  final bool isWritable;

  /// The other person.
  final UserSummary user;

  final String? conversationId;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final int unreadCount;

  MatchSummary copyWith({
    UserSummary? user,
    DateTime? lastMessageAt,
    String? lastMessagePreview,
    int? unreadCount,
  }) {
    return MatchSummary(
      id: id,
      mode: mode,
      isSuperLike: isSuperLike,
      matchedAt: matchedAt,
      expiresAt: expiresAt,
      isExpired: isExpired,
      extensionCount: extensionCount,
      isWritable: isWritable,
      user: user ?? this.user,
      conversationId: conversationId,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

/// Someone who liked the signed-in user and is waiting for an answer.
@immutable
final class LikeReceived {
  const LikeReceived({
    required this.swipeId,
    required this.isSuperLike,
    required this.likedAt,
    required this.user,
  });

  /// Reads one item of `GET /discovery/{mode}/likes-you`.
  factory LikeReceived.fromJson(JsonMap json) {
    if (json case {
      'swipe_id': final String swipeId,
      'is_super_like': final bool isSuperLike,
      'liked_at': final String likedAt,
      'user': final JsonMap user,
    } when swipeId.isNotEmpty) {
      if (DateTime.tryParse(likedAt) case final liked?) {
        return LikeReceived(
          swipeId: swipeId,
          isSuperLike: isSuperLike,
          likedAt: liked,
          user: UserSummary.fromJson(user),
        );
      }
    }
    throw const FormatException(
      'Expected a like with swipe_id, is_super_like, liked_at and user.',
    );
  }

  final String swipeId;
  final bool isSuperLike;
  final DateTime likedAt;
  final UserSummary user;
}
