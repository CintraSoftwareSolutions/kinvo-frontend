import 'package:flutter/foundation.dart';

import '../../../core/network/api_envelope.dart';
import '../../profile/domain/user_summary.dart';

/// A conversation with a match. Every match has exactly one, made with it,
/// in the match's mode.
@immutable
final class Conversation {
  const Conversation({
    required this.id,
    required this.matchId,
    required this.mode,
    required this.user,
    required this.lastMessageAt,
    required this.lastMessagePreview,
    required this.unreadCount,
    required this.isArchived,
    required this.isMuted,
    required this.isWritable,
    required this.matchExpiresAt,
  });

  /// Reads `GET /conversations/{id}`, which `PATCH` also returns.
  factory Conversation.fromJson(JsonMap json) {
    if (json case {
      'id': final String id,
      'match_id': final String matchId,
      'mode': final String mode,
      'user': final JsonMap user,
      'last_message_at': final String? lastMessageAt,
      'last_message_preview': final String? lastMessagePreview,
      'unread_count': final int unreadCount,
      'is_archived': final bool isArchived,
      'is_muted': final bool isMuted,
      'is_writable': final bool isWritable,
      'match_expires_at': final String matchExpiresAt,
    } when id.isNotEmpty && matchId.isNotEmpty) {
      final expires = DateTime.tryParse(matchExpiresAt);
      if (expires != null) {
        return Conversation(
          id: id,
          matchId: matchId,
          mode: mode,
          user: UserSummary.fromJson(user),
          lastMessageAt: lastMessageAt == null
              ? null
              : DateTime.tryParse(lastMessageAt),
          lastMessagePreview: lastMessagePreview,
          unreadCount: unreadCount,
          isArchived: isArchived,
          isMuted: isMuted,
          isWritable: isWritable,
          matchExpiresAt: expires,
        );
      }
    }
    throw const FormatException(
      'Expected a conversation with id, match_id, mode, user, '
      'last_message_at, last_message_preview, unread_count, is_archived, '
      'is_muted, is_writable and match_expires_at.',
    );
  }

  final String id;
  final String matchId;

  /// The match's mode, which the conversation never leaves.
  final String mode;

  /// The other person.
  final UserSummary user;

  final DateTime? lastMessageAt;
  final String? lastMessagePreview;

  /// Messages the user hasn't read.
  final int unreadCount;

  /// Moved out of the Matches list, for the user only.
  final bool isArchived;

  /// No notifications for new messages, for the user only.
  final bool isMuted;

  /// False when the pair can no longer message each other: the match expired
  /// or ended, or one blocked the other. The server doesn't say which, so
  /// nobody can find out they were blocked.
  final bool isWritable;

  final DateTime matchExpiresAt;

  Conversation copyWith({
    UserSummary? user,
    int? unreadCount,
    bool? isArchived,
    bool? isMuted,
    bool? isWritable,
    DateTime? matchExpiresAt,
  }) {
    return Conversation(
      id: id,
      matchId: matchId,
      mode: mode,
      user: user ?? this.user,
      lastMessageAt: lastMessageAt,
      lastMessagePreview: lastMessagePreview,
      unreadCount: unreadCount ?? this.unreadCount,
      isArchived: isArchived ?? this.isArchived,
      isMuted: isMuted ?? this.isMuted,
      isWritable: isWritable ?? this.isWritable,
      matchExpiresAt: matchExpiresAt ?? this.matchExpiresAt,
    );
  }
}
