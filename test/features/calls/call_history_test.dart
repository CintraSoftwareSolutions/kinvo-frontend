import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/features/calls/presentation/screens/call_screen.dart';
import 'package:kinvo/src/features/calls/presentation/screens/calls_screen.dart';
import 'package:kinvo/src/features/chat/presentation/screens/chat_screen.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_kinvo_server.dart';

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

Future<AppHarness> _openCalls(
  WidgetTester tester,
  FakeKinvoServer server,
) async {
  final app = await pumpKinvoApp(
    tester,
    savedSession: liveSession(),
    respond: server.respond,
    realtime: server.realtime,
    clock: server.now,
  );
  await app.pumpUntilFound(find.byType(DiscoverScreen));
  await app.pumpUntilLoaded();

  app.router.go(AppRoutes.calls);
  await app.pumpUntilFound(find.byType(CallsScreen));
  await app.pumpUntilLoaded();
  return app;
}

void main() {
  testWidgets('the list says what happened on each call', (tester) async {
    final server = _server();
    final match = _matchWithSam(server);

    server.calls.addAll([
      FakeCall(
        id: 'call-1',
        matchId: match.id,
        mode: 'dating',
        isInitiator: false,
        createdAt: server.now().subtract(const Duration(hours: 2)),
        status: 'missed',
      ),
      FakeCall(
        id: 'call-2',
        matchId: match.id,
        mode: 'dating',
        kind: 'audio',
        isInitiator: true,
        createdAt: server.now().subtract(const Duration(days: 1)),
        status: 'ended',
      )..durationSeconds = 185,
    ]);

    await _openCalls(tester, server);

    expect(find.text('Sam'), findsNWidgets(2));
    // A call nobody answered says so; "0 seconds" would read as a call that
    // connected in silence.
    expect(find.textContaining('Video · Missed'), findsOneWidget);
    expect(find.textContaining('Voice · 3 min 5 sec'), findsOneWidget);
  });

  testWidgets('calling again from the list keeps the kind', (tester) async {
    final server = _server();
    final match = _matchWithSam(server);
    server.calls.add(
      FakeCall(
        id: 'call-1',
        matchId: match.id,
        mode: 'dating',
        kind: 'audio',
        isInitiator: true,
        createdAt: server.now().subtract(const Duration(hours: 1)),
        status: 'ended',
      ),
    );

    final app = await _openCalls(tester, server);

    await tester.tap(find.byTooltip('Voice call Sam'));
    await app.pumpUntilFound(find.byType(CallScreen));

    // Returning a voice call must not open a camera.
    expect(server.calls.last.kind, 'audio');
    expect(find.text('Voice call'), findsOneWidget);

    await tester.tap(find.text('End'));
    await app.pumpUntilGone(find.byType(CallScreen));
  });

  testWidgets('a row opens the conversation with that person', (tester) async {
    final server = _server();
    final match = _matchWithSam(server);
    server.calls.add(
      FakeCall(
        id: 'call-1',
        matchId: match.id,
        mode: 'dating',
        isInitiator: true,
        createdAt: server.now().subtract(const Duration(minutes: 30)),
        status: 'ended',
      ),
    );

    final app = await _openCalls(tester, server);

    await tester.tap(find.text('Sam').first);
    await app.pumpUntilFound(find.byType(ChatScreen));
    await app.pumpUntilLoaded();
  });

  testWidgets('with no calls it says so, rather than showing nothing', (
    tester,
  ) async {
    final server = _server();
    _matchWithSam(server);

    await _openCalls(tester, server);

    expect(find.text('No calls yet'), findsOneWidget);
  });
}
