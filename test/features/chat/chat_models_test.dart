import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/realtime/realtime_events.dart';
import 'package:kinvo/src/features/chat/data/live_updates.dart';
import 'package:kinvo/src/features/chat/domain/chat_message.dart';
import 'package:kinvo/src/features/chat/domain/conversation.dart';
import 'package:kinvo/src/features/chat/domain/live_update.dart';
import 'package:kinvo/src/features/chat/domain/moderation_check.dart';

Map<String, Object?> _user() {
  return {
    'id': 'p1',
    'display_name': 'Sam',
    'age': 29,
    'primary_photo_url': null,
    'is_verified': false,
    'is_premium': false,
    'is_online': true,
    'last_active_at': '2026-09-17T09:00:00.000Z',
  };
}

Map<String, Object?> _message({
  String type = 'text',
  Object? body = 'Hello',
  Object? readAt,
  Object? durationMs,
}) {
  return {
    'id': 'm1',
    'conversation_id': 'c1',
    'sender_id': 'p1',
    'type': type,
    'body': body,
    'media_url': null,
    'venue_id': null,
    'duration_ms': durationMs,
    'moderation_flagged': false,
    'moderation_overridden': false,
    'read_at': readAt,
    'created_at': '2026-09-17T10:00:00.000Z',
  };
}

void main() {
  group('a message', () {
    test('is read from the API', () {
      final message = ChatMessage.fromJson(
        _message(readAt: '2026-09-17T10:05:00.000Z'),
      );

      expect(message.id, 'm1');
      expect(message.conversationId, 'c1');
      expect(message.senderId, 'p1');
      expect(message.kind, MessageKind.text);
      expect(message.body, 'Hello');
      expect(message.readAt, DateTime.utc(2026, 9, 17, 10, 5));
      expect(message.createdAt, DateTime.utc(2026, 9, 17, 10));
      expect(message.preview, 'Hello');
    });

    test('of a kind this app does not know yet is still read', () {
      final message = ChatMessage.fromJson(_message(type: 'sticker'));

      expect(message.kind, MessageKind.unsupported);
    });

    test('keeps how long a voice note lasts', () {
      final message = ChatMessage.fromJson(
        _message(type: 'voice_note', body: null, durationMs: 12500),
      );

      expect(message.kind, MessageKind.voiceNote);
      expect(message.duration, const Duration(milliseconds: 12500));
      expect(message.preview, 'Voice note');
    });

    test('is refused when a field is missing or malformed', () {
      expect(
        () => ChatMessage.fromJson(_message()..remove('sender_id')),
        throwsFormatException,
      );
      expect(
        () => ChatMessage.fromJson(_message(readAt: 'yesterday')),
        throwsFormatException,
      );
    });
  });

  test('a conversation is read from the API', () {
    final conversation = Conversation.fromJson({
      'id': 'c1',
      'match_id': 'match-1',
      'mode': 'dating',
      'user': _user(),
      'last_message_at': null,
      'last_message_preview': null,
      'unread_count': 2,
      'is_archived': false,
      'is_muted': true,
      'is_writable': false,
      'match_expires_at': '2026-09-30T10:00:00.000Z',
    });

    expect(conversation.matchId, 'match-1');
    expect(conversation.user.displayName, 'Sam');
    expect(conversation.unreadCount, 2);
    expect(conversation.isMuted, isTrue);
    expect(conversation.isWritable, isFalse);
    expect(conversation.matchExpiresAt, DateTime.utc(2026, 9, 30, 10));
  });

  test('a moderation check keeps only what can be shown', () {
    final check = ModerationCheck.fromJson({
      'check_id': 'check-1',
      'severity': 'medium',
      'should_warn': true,
      'can_send': true,
      'findings': [
        {
          'category': 'scam',
          'severity': 'medium',
          'message': 'Mentions money.',
        },
        {'category': 'spam', 'severity': 'low', 'message': '  '},
        'not an object',
      ],
      'timed_out': false,
      'provider': 'rules',
    });

    expect(check.shouldWarn, isTrue);
    expect(check.warnings, ['Mentions money.']);
  });

  group('live events become updates', () {
    LiveUpdate? read(String name, Map<String, Object?> data) {
      return LiveUpdates.read(RealtimeEvent(name, data));
    }

    test('a new message', () {
      final update = read(ServerEvents.messageNew, _message());

      expect(update, isA<MessageReceived>());
      expect((update! as MessageReceived).message.body, 'Hello');
    });

    test('a read receipt', () {
      final update = read(ServerEvents.messageRead, {
        'conversation_id': 'c1',
        'reader_id': 'p1',
        'read_at': '2026-09-17T10:05:00.000Z',
      });

      expect(update, isA<ConversationRead>());
      expect(
        (update! as ConversationRead).readAt,
        DateTime.utc(2026, 9, 17, 10, 5),
      );
    });

    test('typing', () {
      final update = read(ServerEvents.typing, {
        'conversation_id': 'c1',
        'user_id': 'p1',
        'is_typing': true,
      });

      expect(update, isA<TypingChanged>());
      expect((update! as TypingChanged).isTyping, isTrue);
    });

    test('a conversation changing, which also brings it out of Archived', () {
      final update = read(ServerEvents.conversationUpdated, {
        'conversation_id': 'c1',
        'unread_count': 3,
        'last_message_at': '2026-09-17T10:00:00.000Z',
        'last_message_preview': 'Hello',
      });

      expect(update, isA<ConversationActivity>());
      final activity = update! as ConversationActivity;
      expect(activity.unreadCount, 3);
      expect(activity.lastMessagePreview, 'Hello');
      expect(activity.isArchived, isFalse);
    });

    test('someone coming online', () {
      final update = read(ServerEvents.presenceUpdate, {
        'user_id': 'p1',
        'is_online': true,
        'last_active_at': '2026-09-17T10:00:00.000Z',
      });

      expect(update, isA<PresenceChanged>());
      expect((update! as PresenceChanged).isOnline, isTrue);
    });

    test('someone hiding when they are active', () {
      final update = read(ServerEvents.presenceUpdate, {
        'user_id': 'p1',
        'is_online': false,
        'last_active_at': null,
      });

      expect(update, isA<PresenceChanged>());
      expect((update! as PresenceChanged).lastActiveAt, isNull);
    });

    test('a new match', () {
      final update = read(ServerEvents.matchNew, {
        'match_id': 'match-1',
        'conversation_id': 'c1',
        'mode': 'dating',
        'is_super_like': true,
        'matched_at': '2026-09-17T10:00:00.000Z',
        'expires_at': '2026-10-01T10:00:00.000Z',
        'user': _user(),
      });

      expect(update, isA<MatchCreated>());
      final match = (update! as MatchCreated).match;
      expect(match.id, 'match-1');
      expect(match.conversationId, 'c1');
      expect(match.isSuperLike, isTrue);
      expect(match.isWritable, isTrue);
      expect(match.unreadCount, 0);
    });

    test('a changed subscription', () {
      expect(
        read(ServerEvents.entitlementsUpdated, {'tier': 'premium'}),
        isA<SubscriptionChanged>(),
      );
    });

    test('a changed plan, from its notification', () {
      expect(
        read(ServerEvents.notificationNew, {
          'id': 'n1',
          'category': 'plan_update',
          'title': 'Plan confirmed',
          'body': 'Cafe is on.',
          'data': {'plan_id': 'p1', 'match_id': 'm1'},
          'read_at': null,
          'created_at': '2026-09-18T09:00:00.000Z',
        }),
        isA<PlanUpdated>().having((update) => update.planId, 'planId', 'p1'),
      );
      expect(
        read(ServerEvents.notificationNew, {
          'category': 'new_like',
          'data': {'mode': 'dating'},
        }),
        isNull,
      );
    });

    test('but not malformed events, or ones about something else', () {
      expect(read(ServerEvents.messageNew, {'id': 'm1'}), isNull);
      expect(
        read(ServerEvents.typing, {'conversation_id': 'c1', 'user_id': 'p1'}),
        isNull,
      );
      expect(read('call:incoming', {'call_id': 'x'}), isNull);
    });
  });
}
