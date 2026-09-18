import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/realtime/realtime_events.dart';
import '../../../core/realtime/realtime_providers.dart';
import '../../matches/domain/match_summary.dart';
import '../../profile/domain/user_summary.dart';
import '../domain/chat_message.dart';
import '../domain/live_update.dart';

/// Changes to conversations and matches, as they happen: the server's live
/// events, each read once into a [LiveUpdate], together with changes made on
/// this device that other screens should show too.
final class LiveUpdates {
  LiveUpdates(Stream<RealtimeEvent> serverEvents) {
    _subscription = serverEvents.listen((event) {
      if (read(event) case final update?) publish(update);
    });
  }

  final _updates = StreamController<LiveUpdate>.broadcast();
  late final StreamSubscription<RealtimeEvent> _subscription;

  Stream<LiveUpdate> get stream => _updates.stream;

  /// Tells every screen listening about a change made on this device.
  void publish(LiveUpdate update) {
    if (!_updates.isClosed) _updates.add(update);
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _updates.close();
  }

  /// The update [event] describes, or `null` for events that aren't about
  /// conversations or matches, and for malformed ones.
  @visibleForTesting
  static LiveUpdate? read(RealtimeEvent event) {
    final data = event.data;
    try {
      return switch (event.name) {
        ServerEvents.messageNew => MessageReceived(ChatMessage.fromJson(data)),
        ServerEvents.messageRead => _conversationRead(data),
        ServerEvents.typing => _typingChanged(data),
        ServerEvents.conversationUpdated => _conversationActivity(data),
        ServerEvents.presenceUpdate => _presenceChanged(data),
        ServerEvents.matchNew => _matchCreated(data),
        ServerEvents.entitlementsUpdated => const SubscriptionChanged(),
        ServerEvents.notificationNew => _planUpdated(data),
        _ => null,
      };
    } on FormatException catch (error) {
      developer.log(
        'Ignored a malformed "${event.name}" event.',
        name: 'kinvo.chat',
        error: error,
      );
      return null;
    }
  }

  /// A plan notification is how the server says a plan changed. Other
  /// notifications aren't about conversations or matches.
  static PlanUpdated? _planUpdated(JsonMap data) {
    if (data case {'category': 'plan_update', 'data': final JsonMap details}) {
      final planId = details['plan_id'];
      return PlanUpdated(planId: planId is String ? planId : null);
    }
    return null;
  }

  static ConversationRead _conversationRead(JsonMap data) {
    if (data case {
      'conversation_id': final String conversationId,
      'reader_id': final String readerId,
      'read_at': final String readAt,
    }) {
      if (DateTime.tryParse(readAt) case final at?) {
        return ConversationRead(
          conversationId: conversationId,
          readerId: readerId,
          readAt: at,
        );
      }
    }
    throw const FormatException(
      'Expected conversation_id, reader_id and read_at.',
    );
  }

  static TypingChanged _typingChanged(JsonMap data) {
    if (data case {
      'conversation_id': final String conversationId,
      'user_id': final String userId,
      'is_typing': final bool isTyping,
    }) {
      return TypingChanged(
        conversationId: conversationId,
        userId: userId,
        isTyping: isTyping,
      );
    }
    throw const FormatException(
      'Expected conversation_id, user_id and is_typing.',
    );
  }

  static ConversationActivity _conversationActivity(JsonMap data) {
    if (data case {
      'conversation_id': final String conversationId,
      'unread_count': final int unreadCount,
      'last_message_at': final String? lastMessageAt,
      'last_message_preview': final String? lastMessagePreview,
    }) {
      return ConversationActivity(
        conversationId: conversationId,
        unreadCount: unreadCount,
        lastMessageAt: lastMessageAt == null
            ? null
            : DateTime.tryParse(lastMessageAt),
        lastMessagePreview: lastMessagePreview,
        // Only a message arriving sends this, and a message brings an
        // archived conversation back to Matches.
        isArchived: false,
      );
    }
    throw const FormatException(
      'Expected conversation_id, unread_count, last_message_at and '
      'last_message_preview.',
    );
  }

  static PresenceChanged _presenceChanged(JsonMap data) {
    if (data case {
      'user_id': final String userId,
      'is_online': final bool isOnline,
      'last_active_at': final String? lastActiveAt,
    }) {
      // Null when they stopped showing when they're active.
      final at = lastActiveAt == null ? null : DateTime.tryParse(lastActiveAt);
      if (lastActiveAt == null || at != null) {
        return PresenceChanged(
          userId: userId,
          isOnline: isOnline,
          lastActiveAt: at,
        );
      }
    }
    throw const FormatException(
      'Expected user_id, is_online and last_active_at.',
    );
  }

  static MatchCreated _matchCreated(JsonMap data) {
    if (data case {
      'match_id': final String matchId,
      'conversation_id': final String? conversationId,
      'mode': final String mode,
      'is_super_like': final bool isSuperLike,
      'matched_at': final String matchedAt,
      'expires_at': final String expiresAt,
      'user': final JsonMap user,
    }) {
      final matched = DateTime.tryParse(matchedAt);
      final expires = DateTime.tryParse(expiresAt);
      if (matched != null && expires != null) {
        return MatchCreated(
          MatchSummary(
            id: matchId,
            mode: mode,
            isSuperLike: isSuperLike,
            matchedAt: matched,
            expiresAt: expires,
            isExpired: false,
            extensionCount: 0,
            isWritable: true,
            user: UserSummary.fromJson(user),
            conversationId: conversationId,
            lastMessageAt: null,
            lastMessagePreview: null,
            unreadCount: 0,
          ),
        );
      }
    }
    throw const FormatException(
      'Expected match_id, conversation_id, mode, is_super_like, matched_at, '
      'expires_at and user.',
    );
  }
}

/// Live changes to conversations and matches, for as long as the app runs.
/// Nothing arrives from the server while the live connection is closed, as
/// in the demo, but changes made on the device still do.
final liveUpdatesProvider = Provider<LiveUpdates>((ref) {
  final updates = LiveUpdates(ref.watch(realtimeConnectionProvider).events);
  ref.onDispose(updates.dispose);
  return updates;
});
