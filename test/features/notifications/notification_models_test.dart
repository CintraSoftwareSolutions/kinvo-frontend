import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/features/notifications/domain/app_notification.dart';
import 'package:kinvo/src/features/notifications/domain/notification_target.dart';

void main() {
  group('a notification', () {
    Map<String, Object?> json({
      Object? readAt,
      Object? category = 'new_match',
    }) {
      return {
        'id': 'n1',
        'category': category,
        'title': 'It is a match!',
        'body': 'You and Sam liked each other.',
        'data': {'match_id': 'm1', 'conversation_id': 'c1'},
        'read_at': readAt,
        'created_at': '2026-09-17T10:00:00.000Z',
      };
    }

    test('is read from the API', () {
      final notification = AppNotification.fromJson(json());

      expect(notification.category, NotificationCategory.newMatch);
      expect(notification.title, 'It is a match!');
      expect(notification.isUnread, isTrue);
      expect(notification.createdAt, DateTime.utc(2026, 9, 17, 10));
      expect(notification.target, const OpenConversation('c1'));
    });

    test('of a category this app does not know yet is still read', () {
      final notification = AppNotification.fromJson(json(category: 'birthday'));

      expect(notification.category, NotificationCategory.unknown);
      expect(notification.target, const OpenNotifications());
    });

    test('is refused when malformed', () {
      expect(
        () => AppNotification.fromJson(json(readAt: 'yesterday')),
        throwsFormatException,
      );
      expect(
        () => AppNotification.fromJson(json()..remove('data')),
        throwsFormatException,
      );
    });
  });

  test('a preference is read from the API', () {
    final preference = NotificationPreference.fromJson(const {
      'category': 'new_message',
      'push_enabled': false,
      'email_enabled': false,
      'in_app_enabled': true,
    });

    expect(preference.category, NotificationCategory.newMessage);
    expect(preference.pushEnabled, isFalse);
  });

  test('safety notifications are the only ones that stay on', () {
    for (final category in NotificationCategory.values) {
      expect(
        category.canBeSwitchedOff,
        category != NotificationCategory.safety,
        reason: category.name,
      );
    }
  });

  group('opening a notification goes to', () {
    NotificationTarget target(String category, Map<String, Object?> data) {
      return NotificationTarget.of(
        NotificationCategory.fromWireValue(category),
        data,
      );
    }

    test('the conversation, for a message or a match', () {
      expect(
        target('new_message', {'conversation_id': 'c1', 'match_id': 'm1'}),
        const OpenConversation('c1'),
      );
      expect(
        target('new_match', {'conversation_id': 'c1', 'match_id': 'm1'}),
        const OpenConversation('c1'),
      );
    });

    test('the match, when only it is known', () {
      expect(target('new_match', {'match_id': 'm1'}), const OpenMatch('m1'));
      expect(
        target('call', {'call_id': 'x', 'match_id': 'm1'}),
        const OpenMatch('m1'),
      );
      // Push data turns a missing value into the text "null".
      expect(
        target('new_match', {'conversation_id': 'null', 'match_id': 'm1'}),
        const OpenMatch('m1'),
      );
    });

    test('who liked the user, in the mode they were liked in', () {
      expect(
        target('new_like', {'mode': 'dating', 'is_super_like': 'true'}),
        const OpenLikes('dating'),
      );
      expect(target('new_like', const {}), const OpenLikes(null));
    });

    test('a plan, safety, or the list itself', () {
      expect(target('plan_update', {'plan_id': 'p1'}), const OpenPlan('p1'));
      expect(target('plan_update', const {}), const OpenPlans());
      expect(target('safety', {'emergency_id': 'e1'}), const OpenSafety());
      expect(target('system', const {}), const OpenNotifications());
      expect(target('subscription', const {}), const OpenNotifications());
      // The server added this category on 20 September; the app has no
      // verification screen of its own yet.
      expect(
        target('verification', {'verification_id': 'v1'}),
        const OpenNotifications(),
      );
      expect(target('new_message', const {}), const OpenNotifications());
      expect(target('new_match', const {}), const OpenMatches());
    });
  });
}
