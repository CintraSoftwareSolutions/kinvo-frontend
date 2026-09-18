import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/features/chat/presentation/controllers/chat_controller.dart';
import 'package:kinvo/src/features/chat/presentation/screens/chat_screen.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';
import 'package:kinvo/src/features/home/presentation/widgets/home_bottom_nav.dart';
import 'package:kinvo/src/features/matches/presentation/screens/matches_screen.dart';
import 'package:kinvo/src/features/more/presentation/screens/report_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_kinvo_server.dart';

const _sam = FakePerson(id: 'p1', name: 'Sam');

FakeKinvoServer _server() {
  return FakeKinvoServer()
    ..completeProfile()
    ..isOnboarded = true;
}

FakeMatch _matchWithSam(FakeKinvoServer server, {Duration? expiresIn}) {
  final match = FakeMatch(
    id: 'match-p1',
    mode: 'dating',
    person: _sam,
    isSuperLike: false,
    matchedAt: server.now().subtract(const Duration(days: 1)),
    expiresAt: server.now().add(expiresIn ?? const Duration(days: 10)),
  );
  server.matches.add(match);
  return match;
}

/// A signed-in, onboarded account on Discover, with the live connection
/// served by [server].
Future<AppHarness> _launch(WidgetTester tester, FakeKinvoServer server) async {
  final app = await pumpKinvoApp(
    tester,
    savedSession: liveSession(),
    respond: server.respond,
    realtime: server.realtime,
    clock: server.now,
  );
  await app.pumpUntilFound(find.byType(DiscoverScreen));
  await app.pumpUntilLoaded();
  return app;
}

/// Launches the app and opens the conversation with Sam from the Matches tab.
Future<AppHarness> _openChat(
  WidgetTester tester,
  FakeKinvoServer server,
) async {
  final app = await _launch(tester, server);
  app.router.go(AppRoutes.matches);
  await app.pumpUntilFound(find.byType(MatchesScreen));
  await app.pumpUntilLoaded();

  await tester.tap(find.text('Sam'));
  await app.pumpUntilFound(find.byType(ChatScreen));
  await app.pumpUntilLoaded();
  return app;
}

/// Waits for a sheet or dialog to finish opening, then taps [finder] in it.
Future<void> _tapWhenOpen(WidgetTester tester, Finder finder) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(finder);
}

/// Scrolls [finder] into view, then taps it.
Future<void> _scrollToAndTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

void main() {
  testWidgets(
    'opening a match shows the conversation, and sending adds to it',
    (tester) async {
      final server = _server();
      final match = _matchWithSam(server);
      server.addHistory(match, 'Hi there!', fromUser: false, read: false);
      final app = await _openChat(tester, server);

      expect(find.text('Hi there!'), findsOneWidget);

      await _type(tester, 'Hey Sam, how are you?');
      await tester.tap(find.byTooltip('Send'));
      await app.pumpUntilFound(find.textContaining('Sent'));

      expect(find.text('Hey Sam, how are you?'), findsOneWidget);
      expect(match.messages.last.body, 'Hey Sam, how are you?');

      // Opening it read Sam's message, once it had been on screen a moment.
      await tester.pump(ChatController.readDelay);
      await tester.pump();
      expect(match.unreadCount, 0);
    },
  );

  testWidgets(
    'a message moderation warns about is looked at again before it goes',
    (tester) async {
      final server = _server();
      final match = _matchWithSam(server);
      final app = await _openChat(tester, server);

      await _type(tester, 'Can you lend me money?');
      await tester.tap(find.byTooltip('Send'));
      await app.pumpUntilFound(find.text('Review before you send'));
      expect(
        find.text('This message mentions money. Scammers often ask for it.'),
        findsOneWidget,
      );

      await _tapWhenOpen(tester, find.text('Edit message'));
      await app.pumpUntilGone(find.text('Review before you send'));
      // Back in the box, unsent.
      expect(find.text('Can you lend me money?'), findsOneWidget);
      expect(match.messages, isEmpty);

      await tester.tap(find.byTooltip('Send'));
      await app.pumpUntilFound(find.text('Review before you send'));
      await _tapWhenOpen(tester, find.text('Send anyway'));

      await app.pumpUntilFound(find.textContaining('Sent'));
      expect(match.messages.single.overridden, isTrue);
    },
  );

  testWidgets('what the other person does shows as it happens', (tester) async {
    final server = _server();
    final match = _matchWithSam(server);
    final app = await _openChat(tester, server);

    server.typingBy(match, isTyping: true);
    await app.pumpUntilFound(find.textContaining('typing…'));

    server.receiveMessage(match, 'Are you free on Friday?');
    await app.pumpUntilFound(find.text('Are you free on Friday?'));
    expect(find.textContaining('typing…'), findsNothing);
  });

  testWidgets('an expired match can be extended to keep talking', (
    tester,
  ) async {
    final server = _server()..isPremium = true;
    _matchWithSam(server, expiresIn: const Duration(hours: -1));
    final app = await _openChat(tester, server);

    await app.pumpUntilFound(
      find.text('This match has expired. Extend it to keep talking.'),
    );
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Extend match'));
    await app.pumpUntilFound(find.byType(TextField));
    expect(find.textContaining('Extended until'), findsOneWidget);
  });

  testWidgets('reporting from a chat can block, which ends the match', (
    tester,
  ) async {
    final server = _server();
    final match = _matchWithSam(server);
    final message = server.addHistory(
      match,
      'Send me your bank details',
      fromUser: false,
    );
    final app = await _openChat(tester, server);

    await tester.tap(find.byTooltip('Conversation options'));
    await app.pumpUntilFound(find.text('Report Sam'));
    await _tapWhenOpen(tester, find.text('Report Sam'));
    await app.pumpUntilFound(find.byType(ReportScreen));
    await app.pumpUntilLoaded();

    // A reason is needed.
    await _scrollToAndTap(tester, find.text('Submit report'));
    await tester.pump();
    expect(find.text('Choose what happened.'), findsOneWidget);

    await _scrollToAndTap(tester, find.text('Spam or scam'));
    await tester.enterText(find.byType(TextFormField), 'Asked for money.');
    await _scrollToAndTap(tester, find.text('Submit report'));

    await app.pumpUntilFound(
      find.text("Thanks for telling us. You won't see Sam again."),
    );
    await app.pumpUntilGone(find.byType(ChatScreen));
    await app.pumpUntilFound(find.text('No matches yet'));

    expect(server.reports.single, {
      'reported_id': 'p1',
      'reason': 'spam_scam',
      'description': 'Asked for money.',
      'context_type': 'message',
      'context_id': message.id,
      'also_block': true,
    });
    expect(server.matches, isEmpty);
  });

  testWidgets('blocking asks first, then leaves the chat', (tester) async {
    final server = _server();
    _matchWithSam(server);
    final app = await _openChat(tester, server);

    await tester.tap(find.byTooltip('Conversation options'));
    await app.pumpUntilFound(find.text('Block Sam'));
    await _tapWhenOpen(tester, find.text('Block Sam'));

    await app.pumpUntilFound(find.text('Block Sam?'));
    await _tapWhenOpen(tester, find.widgetWithText(TextButton, 'Block'));

    await app.pumpUntilFound(find.text('You blocked Sam.'));
    await app.pumpUntilGone(find.byType(ChatScreen));
    expect(server.blocked, {'p1'});
  });

  testWidgets('a new match is announced, and opens its conversation', (
    tester,
  ) async {
    final server = _server();
    final app = await _launch(tester, server);

    server.matchLive(_sam);
    await app.pumpUntilFound(
      find.text("It's a match! You and Sam like each other."),
    );

    await _tapWhenOpen(tester, find.text('Say hi'));
    await app.pumpUntilFound(find.byType(ChatScreen));
    await app.pumpUntilFound(find.text('Hi Sam! 👋'));
    await app.pumpUntilLoaded();
  });

  testWidgets('the Matches tab counts unread messages as they arrive', (
    tester,
  ) async {
    final server = _server();
    final match = _matchWithSam(server);
    server
      ..addHistory(match, 'Hello?', fromUser: false, read: false)
      ..addHistory(match, 'Anyone there?', fromUser: false, read: false);
    final app = await _launch(tester, server);

    Finder badge(String count) {
      return find.descendant(
        of: find.byType(HomeBottomNav),
        matching: find.text(count),
      );
    }

    await app.pumpUntilFound(badge('2'));

    server.receiveMessage(match, 'I have news');
    await app.pumpUntilFound(badge('3'));
  });
}
