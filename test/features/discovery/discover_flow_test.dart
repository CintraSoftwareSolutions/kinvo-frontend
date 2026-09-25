import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';
import 'package:kinvo/src/features/discovery/presentation/widgets/profile_sheet.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_kinvo_server.dart';

const _ada = FakePerson(id: 'p1', name: 'Ada', isVerified: true);
const _bea = FakePerson(id: 'p2', name: 'Bea');

/// A signed-in, onboarded account on Discover, against [server].
Future<AppHarness> _openDiscover(
  WidgetTester tester,
  FakeKinvoServer server,
) async {
  final app = await pumpKinvoApp(
    tester,
    savedSession: liveSession(),
    respond: server.respond,
    // The server's time, so what cards say about when people were last
    // active doesn't change with the day the tests run.
    clock: server.now,
  );
  await app.pumpUntilFound(find.byType(DiscoverScreen));
  await app.pumpUntilLoaded();
  return app;
}

FakeKinvoServer _server({List<FakePerson> deck = const [_ada, _bea]}) {
  return FakeKinvoServer()
    ..completeProfile()
    ..isOnboarded = true
    ..decks['dating'] = [...deck];
}

/// The widget carrying the accessibility label [label].
Finder _labelled(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
  );
}

/// Scrolls [finder] into view, then taps it. The deck controls sit below
/// the card, under the fold on a phone.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

void main() {
  testWidgets('a like that comes back is a match', (tester) async {
    final server = _server()..likesBack.add('p1');
    final app = await _openDiscover(tester, server);

    expect(find.text('Ada'), findsOneWidget);
    await _tap(tester, _labelled('Like'));

    await app.pumpUntilFound(find.text("It's a match!"));
    expect(
      find.text('You and Ada liked each other in Dating.'),
      findsOneWidget,
    );

    await _tap(tester, find.text('Keep discovering'));
    await app.pumpUntilFound(find.text('Bea'));
    await app.pumpUntilLoaded();
    expect(server.matches.single.person.id, 'p1');
  });

  testWidgets('used-up likes explain themselves and keep the card', (
    tester,
  ) async {
    final server = _server()
      ..dailyLikes = 50
      ..likesUsed = 50;
    final app = await _openDiscover(tester, server);

    await _tap(tester, _labelled('Like'));

    await app.pumpUntilFound(find.text("That's today's allowance"));
    expect(
      find.text(
        'You have used all 50 swipes for today. Upgrade for unlimited.',
      ),
      findsOneWidget,
    );

    // Let the sheet finish sliding up before tapping inside it.
    await tester.pump(const Duration(milliseconds: 500));
    await _tap(tester, find.text('Not now'));
    await app.pumpUntilGone(find.text("That's today's allowance"));

    expect(find.text('Ada'), findsOneWidget);
    expect(server.likesUsed, 50);
  });

  testWidgets('answering the last card shows the empty deck', (tester) async {
    final server = _server(deck: [_ada]);
    final app = await _openDiscover(tester, server);

    await _tap(tester, _labelled('Pass'));

    await app.pumpUntilFound(find.text("You're all caught up in Dating"));
    await app.pumpUntilLoaded();
    // Passing never uses the allowance.
    expect(server.likesUsed, 0);
  });

  testWidgets('saved filters change who is in the deck', (tester) async {
    final server = _server(deck: [_bea, _ada]);
    final app = await _openDiscover(tester, server);
    expect(find.text('Bea'), findsOneWidget);

    await _tap(tester, _labelled('Filters'));
    await app.pumpUntilFound(find.text('Dating filters'));
    // Let the sheet finish sliding up before tapping inside it.
    await tester.pump(const Duration(milliseconds: 500));
    await _tap(tester, find.text('Verified people only'));
    await tester.pump();
    await _tap(tester, find.text('Save filters'));

    // Only Ada is verified.
    await app.pumpUntilFound(find.text('Ada'));
    await app.pumpUntilLoaded();
    // Bea's card fades out as Ada's comes in.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Bea'), findsNothing);
    expect(server.modeFilters['dating'], containsPair('verified_only', true));
  });

  testWidgets('a card opens the full profile', (tester) async {
    final server = _server();
    final app = await _openDiscover(tester, server);

    await _tap(tester, find.text('Tap to see the full profile'));

    await app.pumpUntilFound(find.text('INTERESTS'));
    await app.pumpUntilLoaded();
    final sheet = find.byType(ProfileSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('Music')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Ada, 29')),
      findsOneWidget,
    );
  });

  group('rewinding a swipe that became a match', () {
    /// Likes Ada, who liked back, and carries on to Bea.
    Future<AppHarness> matchWithAda(
      WidgetTester tester,
      FakeKinvoServer server,
    ) async {
      final app = await _openDiscover(tester, server);
      await _tap(tester, _labelled('Like'));
      await app.pumpUntilFound(find.text("It's a match!"));
      await _tap(tester, find.text('Keep discovering'));
      await app.pumpUntilFound(find.text('Bea'));
      await app.pumpUntilLoaded();
      return app;
    }

    testWidgets('keeps the match, and offers Unmatch instead', (tester) async {
      final server = _server()
        ..isPremium = true
        ..likesBack.add('p1');
      final app = await matchWithAda(tester, server);

      await _tap(tester, _labelled('Rewind last swipe'));
      await app.pumpUntilFound(find.text('You matched with Ada'));

      // Keeping it changes nothing.
      await tester.tap(find.text('Keep match'));
      await app.pumpUntilGone(find.text('You matched with Ada'));
      expect(server.matches.single.person.id, 'p1');
      expect(find.text('Bea'), findsOneWidget);

      await _tap(tester, _labelled('Rewind last swipe'));
      await app.pumpUntilFound(find.text('You matched with Ada'));
      await tester.tap(find.text('Unmatch'));
      await app.pumpUntilFound(find.text('You unmatched Ada.'));

      expect(server.matches, isEmpty);
      // Unmatching ends the match; it doesn't bring the card back.
      expect(server.swipes['dating']!.single.userId, 'p1');
      expect(find.text('Bea'), findsOneWidget);
      await app.pumpUntilLoaded();
    });

    testWidgets('says so, with nothing to offer, once the match has ended', (
      tester,
    ) async {
      final server = _server()
        ..isPremium = true
        ..likesBack.add('p1');
      final app = await matchWithAda(tester, server);
      // Ended since, by Ada.
      server
        ..matches.clear()
        ..endedMatches.add('dating:p1');

      await _tap(tester, _labelled('Rewind last swipe'));
      await app.pumpUntilFound(
        find.text(
          'You matched with this person, so that swipe cannot be undone.',
        ),
      );

      expect(find.text('Unmatch'), findsNothing);
      expect(find.text('Bea'), findsOneWidget);
      await app.pumpUntilLoaded();
    });
  });
}
