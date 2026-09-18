import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/auth/auth_providers.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/core/push/push_messaging.dart';
import 'package:kinvo/src/features/chat/presentation/screens/chat_screen.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';
import 'package:kinvo/src/features/discovery/presentation/widgets/discover_header.dart';
import 'package:kinvo/src/features/matches/presentation/screens/matches_screen.dart';
import 'package:kinvo/src/features/notifications/presentation/push_messages.dart';
import 'package:kinvo/src/features/notifications/presentation/screens/notification_settings_screen.dart';
import 'package:kinvo/src/features/notifications/presentation/screens/notifications_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_kinvo_server.dart';
import '../../helpers/fake_push_messaging.dart';
import '../../helpers/test_backend.dart';

const _sam = FakePerson(id: 'p1', name: 'Sam');

FakeKinvoServer _server() {
  return FakeKinvoServer()
    ..completeProfile()
    ..isOnboarded = true;
}

FakeMatch _matchWithSam(FakeKinvoServer server) {
  final match = FakeMatch(
    id: 'match-p1',
    mode: 'dating',
    person: _sam,
    isSuperLike: false,
    matchedAt: server.now().subtract(const Duration(days: 1)),
    expiresAt: server.now().add(const Duration(days: 10)),
  );
  server.matches.add(match);
  return match;
}

/// A signed-in, onboarded account on Discover.
Future<AppHarness> _launch(
  WidgetTester tester,
  FakeKinvoServer server, {
  FakePushMessaging? push,
}) async {
  final app = await pumpKinvoApp(
    tester,
    savedSession: liveSession(),
    respond: server.respond,
    realtime: server.realtime,
    push: push,
    clock: server.now,
  );
  await app.pumpUntilFound(find.byType(DiscoverScreen));
  await app.pumpUntilLoaded();
  return app;
}

/// The bell on Discover, whose label says how many are unread.
Finder _bell() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Semantics &&
        (widget.properties.label?.startsWith('Notifications') ?? false),
  );
}

Finder _bellCount(String count) {
  return find.descendant(
    of: find.byType(DiscoverHeader),
    matching: find.text(count),
  );
}

/// Waits for a sheet or dialog to finish opening, then taps [finder] in it.
Future<void> _tapWhenOpen(WidgetTester tester, Finder finder) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(finder);
}

PushMessage _messagePush(FakeMatch match, {String? notificationId}) {
  return PushMessage(
    title: 'Sam',
    body: 'Are you free on Friday?',
    data: {
      'category': 'new_message',
      'conversation_id': match.conversationId,
      'match_id': match.id,
      'notification_id': ?notificationId,
    },
  );
}

void main() {
  testWidgets('the bell counts unread notifications, and opening one goes to '
      'what it is about', (tester) async {
    final server = _server();
    final match = _matchWithSam(server);
    final notification = server.addNotification(
      'new_message',
      'Sam',
      'Are you free on Friday?',
      data: {'conversation_id': match.conversationId, 'match_id': match.id},
    );
    server.addNotification(
      'system',
      'Welcome to Kinvo',
      'Say hello to your matches.',
      read: true,
      ago: const Duration(days: 2),
    );
    final app = await _launch(tester, server);

    await app.pumpUntilFound(_bellCount('1'));
    await tester.tap(_bell());
    await app.pumpUntilFound(find.byType(NotificationsScreen));
    await app.pumpUntilLoaded();
    expect(find.text('Welcome to Kinvo'), findsOneWidget);

    await tester.tap(find.text('Are you free on Friday?'));
    await app.pumpUntilFound(find.byType(ChatScreen));
    await app.pumpUntilLoaded();

    expect(notification.readAt, isNotNull);
  });

  testWidgets('marking all read clears the list and the bell', (tester) async {
    final server = _server()
      ..addNotification('system', 'One', 'First')
      ..addNotification('new_like', 'Someone liked you', 'Open Kinvo');
    final app = await _launch(tester, server);
    await app.pumpUntilFound(_bellCount('2'));

    unawaited(app.router.push<void>(AppRoutes.notifications));
    await app.pumpUntilFound(find.text('Mark all read'));
    await app.pumpUntilLoaded();
    await tester.tap(find.text('Mark all read'));
    await app.pumpUntilGone(find.text('Mark all read'));

    expect(server.notifications.every((each) => each.readAt != null), isTrue);
    await tester.tap(find.byTooltip('Back'));
    await app.pumpUntilGone(find.byType(NotificationsScreen));
    await app.pumpUntilGone(_bellCount('2'));
  });

  testWidgets('a notification arriving shows in the list at once', (
    tester,
  ) async {
    final server = _server();
    final app = await _launch(tester, server);
    unawaited(app.router.push<void>(AppRoutes.notifications));
    await app.pumpUntilFound(find.text("You're all caught up"));

    server.notifyLive(
      'new_like',
      'Someone liked you',
      'Open Kinvo to see who.',
    );

    await app.pumpUntilFound(find.text('Someone liked you'));
    expect(find.text("You're all caught up"), findsNothing);
  });

  group('settings', () {
    Future<AppHarness> openSettings(
      WidgetTester tester,
      FakeKinvoServer server,
      FakePushMessaging push,
    ) async {
      final app = await _launch(tester, server, push: push);
      app.router.go(AppRoutes.settings);
      await app.pumpUntilFound(find.text('Notifications'));
      await tester.tap(find.text('Notifications'));
      await app.pumpUntilFound(find.byType(NotificationSettingsScreen));
      await app.pumpUntilLoaded();
      return app;
    }

    testWidgets('choose which notifications arrive as pushes', (tester) async {
      final server = _server();
      await openSettings(tester, server, FakePushMessaging());

      expect(find.text('On for this phone'), findsOneWidget);

      final messages = find.widgetWithText(SwitchListTile, 'Messages');
      await tester.ensureVisible(messages);
      await tester.pump();
      await tester.tap(messages);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(server.pushOff, {'new_message'});

      final safety = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Safety'),
      );
      expect(safety.value, isTrue);
      expect(safety.onChanged, isNull);
    });

    testWidgets("send a phone that blocks notifications to its settings", (
      tester,
    ) async {
      final app = await openSettings(
        tester,
        _server(),
        FakePushMessaging(permissionState: PushPermission.blocked),
      );

      expect(find.text("Off in your phone's settings"), findsOneWidget);
      await tester.tap(find.text('Open settings'));
      await tester.pump();

      expect(app.backend.locationService.appSettingsOpened, 1);
    });

    testWidgets("say push is unavailable when the phone can't be asked", (
      tester,
    ) async {
      await openSettings(
        tester,
        _server(),
        FakePushMessaging()
          ..permissionFailure = Exception('Firebase could not start'),
      );

      expect(find.text('Push notifications are unavailable'), findsOneWidget);
      expect(find.text('Turn on'), findsNothing);
      // The kinds of notification can still be chosen.
      expect(find.widgetWithText(SwitchListTile, 'Messages'), findsOneWidget);
    });
  });

  testWidgets('invites the user to turn notifications on, then registers the '
      'phone', (tester) async {
    final server = _server();
    final push = FakePushMessaging(permissionState: PushPermission.requestable)
      ..promptAnswer = PushPermission.granted;
    final app = await _launch(tester, server, push: push);
    expect(server.pushTokens, isEmpty);

    await app.pumpUntilFound(find.text("Don't miss a match"));
    await _tapWhenOpen(tester, find.text('Turn on notifications'));
    await app.pumpUntilGone(find.text("Don't miss a match"));
    await app.pumpUntil(
      () => server.pushTokens.isNotEmpty,
      reason: 'this phone is registered',
    );

    expect(push.permissionRequests, 1);
    expect(server.pushTokens, {testDeviceId: 'fcm-token-1'});
  });

  group('push notifications', () {
    testWidgets('keep this phone registered while signed in, and throw the '
        'token away on signing out', (tester) async {
      final server = _server();
      final push = FakePushMessaging();
      final app = await _launch(tester, server, push: push);

      expect(server.pushTokens, {testDeviceId: 'fcm-token-1'});

      push.rotateToken();
      await app.pumpUntil(
        () => server.pushTokens[testDeviceId] == 'fcm-token-2',
        reason: 'the new token is registered',
      );

      unawaited(app.container.read(sessionManagerProvider).signOut());
      await app.pumpUntilFound(find.text('Create Account'));
      expect(push.tokensDeleted, 1);
    });

    testWidgets('tapped in the background, open the conversation', (
      tester,
    ) async {
      final server = _server();
      final match = _matchWithSam(server);
      final notification = server.addNotification(
        'new_message',
        'Sam',
        'Are you free on Friday?',
        data: {'conversation_id': match.conversationId},
      );
      final push = FakePushMessaging();
      final app = await _launch(tester, server, push: push);

      push.tap(_messagePush(match, notificationId: notification.id));

      await app.pumpUntilFound(find.byType(ChatScreen));
      await app.pumpUntilLoaded();
      expect(notification.readAt, isNotNull);
    });

    testWidgets('that launched the app open once the session is ready', (
      tester,
    ) async {
      final server = _server();
      final match = _matchWithSam(server);
      final push = FakePushMessaging()..launchedBy = _messagePush(match);

      final app = await pumpKinvoApp(
        tester,
        savedSession: liveSession(),
        respond: server.respond,
        realtime: server.realtime,
        push: push,
      );

      await app.pumpUntilFound(find.byType(ChatScreen));
      await app.pumpUntilLoaded();
      expect(find.text('Sam'), findsWidgets);

      await tester.tap(find.byTooltip('Back'));
      await app.pumpUntilFound(find.byType(MatchesScreen));
      await app.pumpUntilLoaded();
      expect(find.byType(ChatScreen), findsNothing);
    });

    testWidgets('arriving in the app show a banner, but not for the '
        'conversation already open', (tester) async {
      final server = _server();
      final match = _matchWithSam(server);
      final push = FakePushMessaging();
      final app = await _launch(tester, server, push: push);

      push.arrive(_messagePush(match));
      await app.pumpUntilFound(find.byType(PushBannerContent));
      await _tapWhenOpen(tester, find.text('View'));
      await app.pumpUntilFound(find.byType(ChatScreen));
      await app.pumpUntilLoaded();
      await app.pumpUntilGone(find.byType(PushBannerContent));

      push.arrive(_messagePush(match));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PushBannerContent), findsNothing);
    });
  });

  testWidgets('the demo has sample notifications, offline', (tester) async {
    final app = await pumpKinvoApp(tester);
    await app.pumpUntilFound(find.text('Explore Demo'));
    await tester.tap(find.text('Explore Demo'));
    await app.pumpUntilFound(find.byType(DiscoverScreen));
    await app.pumpUntilLoaded();

    await app.pumpUntilFound(_bellCount('2'));
    await tester.tap(_bell());
    await app.pumpUntilFound(find.text('It is a match!'));
    await app.pumpUntilLoaded();

    expect(app.adapter.requests, isEmpty);
  });
}
