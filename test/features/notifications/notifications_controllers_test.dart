import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/auth/account_providers.dart';
import 'package:kinvo/src/core/auth/auth_providers.dart';
import 'package:kinvo/src/core/push/push_messaging.dart';
import 'package:kinvo/src/core/realtime/realtime_providers.dart';
import 'package:kinvo/src/features/chat/data/chat_repository.dart';
import 'package:kinvo/src/features/chat/data/live_updates.dart';
import 'package:kinvo/src/features/chat/domain/live_update.dart';
import 'package:kinvo/src/features/notifications/domain/app_notification.dart';
import 'package:kinvo/src/features/notifications/presentation/controllers/notifications_controllers.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/auth_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_kinvo_server.dart';
import '../../helpers/fake_push_messaging.dart';
import '../../helpers/test_backend.dart';

void main() {
  // Counts refresh when the app comes back to the screen, which they ask the
  // Flutter binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeKinvoServer server;
  late FakePushMessaging push;
  late TestBackend backend;
  late ProviderContainer container;

  setUp(() async {
    server = FakeKinvoServer()
      ..completeProfile()
      ..isOnboarded = true;
    push = FakePushMessaging();
    backend = TestBackend(
      respond: server.respond,
      realtime: server.realtime,
      push: push,
    );
    await backend.tokenStore.write(liveSession());
    container = backend.createContainer();
    await container.read(sessionManagerProvider).ready;
  });

  /// Waits out the pause before a count is read again.
  Future<void> waitForCount() async {
    await Future<void>.delayed(
      NotificationUnreadCountController.settleDelay +
          const Duration(milliseconds: 100),
    );
    await settle();
  }

  group('the feed', () {
    Future<NotificationsFeedController> openFeed() async {
      container.listen(notificationsFeedProvider, (_, _) {});
      await container.read(notificationsFeedProvider.future);
      return container.read(notificationsFeedProvider.notifier);
    }

    List<String> titles() {
      return [
        for (final notification
            in container.read(notificationsFeedProvider).requireValue.items)
          notification.title,
      ];
    }

    test('lists notifications newest first, a page at a time', () async {
      for (var i = 1; i <= 35; i++) {
        server.addNotification(
          'system',
          'Notice $i',
          'Body',
          ago: Duration(minutes: 100 - i),
        );
      }

      final feed = await openFeed();
      expect(titles(), hasLength(30));
      expect(titles().first, 'Notice 35');

      await feed.loadMore();
      expect(titles(), hasLength(35));
      expect(titles().last, 'Notice 1');
    });

    test('adds a notification the moment it arrives', () async {
      server.addNotification('system', 'Older', 'Body');
      container.read(realtimeConnectionProvider).setWanted(true);
      await settle();
      await openFeed();

      server.notifyLive('new_like', 'Someone liked you', 'Open Kinvo');
      await settle();

      expect(titles(), ['Someone liked you', 'Older']);
    });

    test('opening one marks it read', () async {
      final notification = server.addNotification('system', 'Hello', 'Body');
      container.listen(notificationUnreadCountProvider, (_, _) {});
      expect(await container.read(notificationUnreadCountProvider.future), 1);
      final feed = await openFeed();

      feed.opened(
        container.read(notificationsFeedProvider).requireValue.items.single,
      );
      await settle();

      expect(notification.readAt, isNotNull);
      expect(
        container
            .read(notificationsFeedProvider)
            .requireValue
            .items
            .single
            .isUnread,
        isFalse,
      );
      expect(container.read(notificationUnreadCountProvider).value, 0);
    });

    test('marks everything read at once', () async {
      server
        ..addNotification('system', 'One', 'Body')
        ..addNotification('new_like', 'Two', 'Body');
      final feed = await openFeed();

      expect(await feed.markAllRead(), isNull);

      expect(server.notifications.every((each) => each.readAt != null), isTrue);
      expect(
        container
            .read(notificationsFeedProvider)
            .requireValue
            .items
            .any((each) => each.isUnread),
        isFalse,
      );
    });
  });

  group('the unread count', () {
    Future<int> openCount() async {
      container.listen(notificationUnreadCountProvider, (_, _) {});
      return container.read(notificationUnreadCountProvider.future);
    }

    test('goes up as notifications arrive', () async {
      container.read(realtimeConnectionProvider).setWanted(true);
      await settle();
      expect(await openCount(), 0);

      server.notifyLive('new_match', 'It is a match!', 'You and Sam');
      await waitForCount();

      expect(container.read(notificationUnreadCountProvider).value, 1);
    });

    test(
      'goes down when reading a conversation reads its notifications',
      () async {
        final match = FakeMatch(
          id: 'match-p1',
          mode: 'dating',
          person: const FakePerson(id: 'p1', name: 'Sam'),
          isSuperLike: false,
          matchedAt: server.now(),
          expiresAt: server.now().add(const Duration(days: 10)),
        );
        server
          ..matches.add(match)
          ..addNotification(
            'new_message',
            'Sam',
            'Hi',
            data: {'conversation_id': match.conversationId},
          );
        expect(await openCount(), 1);

        // As the chat does: marks the conversation read, then says so.
        await container
            .read(chatRepositoryProvider)
            .markRead(match.conversationId);
        container
            .read(liveUpdatesProvider)
            .publish(
              ConversationActivity(
                conversationId: match.conversationId,
                unreadCount: 0,
              ),
            );
        await waitForCount();

        expect(container.read(notificationUnreadCountProvider).value, 0);
      },
    );

    test("puts the account's count on the app icon", () async {
      server.addNotification('system', 'Hello', 'Body');

      expect(await openCount(), 1);
      await settle();

      expect(backend.iconBadge.shown, [1]);
    });
  });

  group('preferences', () {
    Future<NotificationPreferencesController> openPreferences() async {
      container.listen(notificationPreferencesProvider, (_, _) {});
      await container.read(notificationPreferencesProvider.future);
      return container.read(notificationPreferencesProvider.notifier);
    }

    bool pushFor(NotificationCategory category) {
      return container
          .read(notificationPreferencesProvider)
          .requireValue
          .singleWhere((each) => each.category == category)
          .pushEnabled;
    }

    test('turn one kind of push off, and back on', () async {
      final preferences = await openPreferences();

      expect(
        await preferences.setPush(NotificationCategory.newMessage, false),
        isNull,
      );
      expect(pushFor(NotificationCategory.newMessage), isFalse);
      expect(server.pushOff, {'new_message'});

      await preferences.setPush(NotificationCategory.newMessage, true);
      expect(server.pushOff, isEmpty);
    });

    test('put a change back when it cannot be saved', () async {
      server.intercept = (options) async {
        if (options.method == 'PATCH') {
          return jsonResponse(
            503,
            errorEnvelope('SERVICE_UNAVAILABLE', 'Please try again shortly.'),
          );
        }
        return null;
      };
      final preferences = await openPreferences();

      expect(
        await preferences.setPush(NotificationCategory.newLike, false),
        'Please try again shortly.',
      );
      expect(pushFor(NotificationCategory.newLike), isTrue);
    });

    test('never switch safety off', () async {
      final preferences = await openPreferences();

      expect(
        await preferences.setPush(NotificationCategory.safety, false),
        isNotNull,
      );
      expect(pushFor(NotificationCategory.safety), isTrue);
      expect(backend.requestsTo('/notifications/preferences/safety'), isEmpty);
    });
  });

  group('the invitation to turn notifications on', () {
    Future<bool> invite() async {
      container.listen(pushInvitationProvider, (_, _) {});
      await container.read(currentAccountProvider.future);
      return container.read(pushInvitationProvider.future);
    }

    test('is offered once, on a phone that can still be asked', () async {
      push.permissionState = PushPermission.requestable;

      expect(await invite(), isTrue);

      await container.read(pushInvitationProvider.notifier).offered();
      container.invalidate(pushInvitationProvider);
      expect(await container.read(pushInvitationProvider.future), isFalse);
    });

    test(
      'is not offered where notifications are already on, or blocked',
      () async {
        push.permissionState = PushPermission.granted;
        expect(await invite(), isFalse);

        push.permissionState = PushPermission.blocked;
        container.invalidate(pushInvitationProvider);
        expect(await container.read(pushInvitationProvider.future), isFalse);
      },
    );

    test('waits until the account is set up', () async {
      server.isOnboarded = false;
      push.permissionState = PushPermission.requestable;

      expect(await invite(), isFalse);
    });
  });

  test('allowing notifications registers this device', () async {
    push
      ..permissionState = PushPermission.requestable
      ..promptAnswer = PushPermission.granted;
    container.listen(pushPermissionProvider, (_, _) {});
    await container.read(pushPermissionProvider.future);

    final answer = await container
        .read(pushPermissionProvider.notifier)
        .request();
    await settle();

    expect(answer, PushPermission.granted);
    expect(server.pushTokens, {testDeviceId: 'fcm-token-1'});
  });

  test('a device that cannot be asked is left as it was', () async {
    push.permissionFailure = Exception('No activity to ask from');
    container.listen(pushPermissionProvider, (_, _) {});
    await expectLater(
      container.read(pushPermissionProvider.future),
      throwsException,
    );

    final answer = await container
        .read(pushPermissionProvider.notifier)
        .request();
    await settle();

    expect(answer, isNull);
    expect(backend.requestsTo('/notifications/tokens'), isEmpty);
  });
}
