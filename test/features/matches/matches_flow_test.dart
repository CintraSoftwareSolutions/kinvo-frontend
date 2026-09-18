import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/features/chat/presentation/screens/chat_screen.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';
import 'package:kinvo/src/features/matches/presentation/screens/matches_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_kinvo_server.dart';

const _sam = FakePerson(id: 'p1', name: 'Sam');
const _alex = FakePerson(id: 'p2', name: 'Alex');

/// A signed-in, onboarded account on the Matches tab, against [server].
Future<AppHarness> _openMatches(
  WidgetTester tester,
  FakeKinvoServer server,
) async {
  final app = await pumpKinvoApp(
    tester,
    savedSession: liveSession(),
    respond: server.respond,
    // The app's "2 days ago" and the server's timestamps share one clock.
    clock: server.now,
  );
  await app.pumpUntilFound(find.byType(DiscoverScreen));
  await app.pumpUntilLoaded();
  app.router.go(AppRoutes.matches);
  await app.pumpUntilFound(find.byType(MatchesScreen));
  await app.pumpUntilLoaded();
  return app;
}

FakeKinvoServer _server() {
  return FakeKinvoServer()
    ..completeProfile()
    ..isOnboarded = true;
}

FakeMatch _matchWith(FakeKinvoServer server, FakePerson person) {
  return FakeMatch(
    id: 'match-${person.id}',
    mode: 'dating',
    person: person,
    isSuperLike: false,
    matchedAt: server.now().subtract(const Duration(days: 2)),
    expiresAt: server.now().add(const Duration(days: 12)),
  );
}

/// Waits for a sheet or dialog to finish opening, then taps [finder] in it.
Future<void> _tapWhenOpen(WidgetTester tester, Finder finder) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(finder);
}

void main() {
  testWidgets('matches are listed, and unmatching from a chat asks first', (
    tester,
  ) async {
    final server = _server();
    server.matches.addAll([
      _matchWith(server, _sam),
      _matchWith(server, _alex),
    ]);
    final app = await _openMatches(tester, server);

    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Matched 2 days ago'), findsNWidgets(2));

    await tester.tap(find.text('Sam'));
    await app.pumpUntilFound(find.byType(ChatScreen));
    await app.pumpUntilLoaded();

    await tester.tap(find.byTooltip('Conversation options'));
    await app.pumpUntilFound(find.text('Unmatch'));
    await _tapWhenOpen(tester, find.text('Unmatch'));

    await app.pumpUntilFound(find.text('Unmatch Sam?'));
    await _tapWhenOpen(tester, find.widgetWithText(TextButton, 'Unmatch'));

    await app.pumpUntilFound(find.text('You unmatched Sam.'));
    await app.pumpUntilGone(find.byType(ChatScreen));
    expect(find.text('Sam'), findsNothing);
    expect(find.text('Alex'), findsOneWidget);
    expect(server.matches.map((match) => match.id), ['match-p2']);
  });

  testWidgets('with no matches yet, the tab says how they arrive', (
    tester,
  ) async {
    await _openMatches(tester, _server());

    expect(find.text('No matches yet'), findsOneWidget);
  });

  testWidgets('who likes you is locked without Premium, but counted', (
    tester,
  ) async {
    final server = _server()..likesYou['dating'] = [_sam, _alex];
    final app = await _openMatches(tester, server);

    await tester.tap(find.text('Likes you'));
    await app.pumpUntilFound(find.text('2 people like you'));
    await app.pumpUntilLoaded();
    expect(find.text('Sam'), findsNothing);

    await tester.tap(find.text('See who likes you'));
    await app.pumpUntilFound(find.text('Part of Premium'));
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('liking someone back from the inbox makes a match', (
    tester,
  ) async {
    final server = _server()
      ..isPremium = true
      ..likesYou['dating'] = [_sam]
      ..likesBack.add('p1');
    final app = await _openMatches(tester, server);

    await tester.tap(find.text('Likes you'));
    await app.pumpUntilFound(find.text('Sam, 29'));
    await app.pumpUntilLoaded();

    await tester.tap(find.text('Sam, 29'));
    await app.pumpUntilFound(find.widgetWithText(FilledButton, 'Like'));
    await _tapWhenOpen(tester, find.widgetWithText(FilledButton, 'Like'));

    await app.pumpUntilFound(find.text("It's a match!"));
    await _tapWhenOpen(tester, find.text('See your matches'));

    await app.pumpUntilFound(find.text('Matched just now'));
    await app.pumpUntilLoaded();
    expect(server.matches.single.person.id, 'p1');
  });
}
