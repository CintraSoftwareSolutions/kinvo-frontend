import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/core/realtime/realtime_events.dart';
import 'package:kinvo/src/features/calls/presentation/controllers/call_controller.dart';
import 'package:kinvo/src/features/calls/presentation/screens/call_screen.dart';
import 'package:kinvo/src/features/chat/presentation/screens/chat_screen.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';
import 'package:kinvo/src/features/matches/presentation/screens/matches_screen.dart';

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

/// Opens the conversation with Sam, where the call button lives.
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

void main() {
  testWidgets('calling from a chat rings, and hanging up ends it', (
    tester,
  ) async {
    final server = _server();
    final match = _matchWithSam(server);
    final app = await _openChat(tester, server);

    await tester.tap(find.byTooltip('Video call'));
    await app.pumpUntilFound(find.byType(CallScreen));

    // Ringing, from the caller's side.
    expect(find.text('Calling…'), findsOneWidget);
    expect(server.calls.single.matchId, match.id);
    expect(server.calls.single.status, 'ringing');

    await tester.tap(find.text('End'));
    await app.pumpUntilGone(find.byType(CallScreen));

    // Nobody answered, so the server records it as missed rather than a call
    // that lasted no time.
    expect(server.calls.single.status, 'missed');
    expect(server.calls.single.durationSeconds, isNull);
    expect(find.byType(ChatScreen), findsOneWidget);
  });

  testWidgets('the phone button starts a voice call, not a video one', (
    tester,
  ) async {
    final server = _server();
    _matchWithSam(server);
    final app = await _openChat(tester, server);

    await tester.tap(find.byTooltip('Voice call'));
    await app.pumpUntilFound(find.byType(CallScreen));

    // The server is told which kind it is, because the other phone decides
    // whether to open its camera and this is all it has to go on.
    expect(server.calls.single.kind, 'audio');
    expect(find.text('Voice call'), findsOneWidget);

    await tester.tap(find.text('End'));
    await app.pumpUntilGone(find.byType(CallScreen));
  });

  testWidgets('an incoming voice call says so before it is answered', (
    tester,
  ) async {
    final server = _server();
    final match = _matchWithSam(server);
    final app = await _launch(tester, server);

    server.calls.add(
      FakeCall(
        id: 'call-1',
        matchId: match.id,
        mode: 'dating',
        kind: 'audio',
        isInitiator: false,
        createdAt: server.now(),
      ),
    );
    server.realtime.push(ServerEvents.callIncoming, {
      'call_id': 'call-1',
      'match_id': match.id,
      'mode': 'dating',
      'kind': 'audio',
      'from': _sam.compact(server.now()),
    });

    await app.pumpUntilFound(find.byType(CallScreen));
    expect(find.text('Voice call'), findsOneWidget);
    expect(find.text('Incoming'), findsOneWidget);
    // Answering with a camera icon promises a video call nobody asked for.
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    expect(find.byIcon(Icons.videocam_rounded), findsNothing);

    await tester.tap(find.text('Decline'));
    await app.pumpUntilGone(find.byType(CallScreen));
  });

  testWidgets('the other person answering makes it a call', (tester) async {
    final server = _server();
    _matchWithSam(server);
    final app = await _openChat(tester, server);

    await tester.tap(find.byTooltip('Video call'));
    await app.pumpUntilFound(find.byType(CallScreen));

    final callId = server.calls.single.id;
    server.calls.single
      ..status = 'active'
      ..answeredAt = server.now();
    server.realtime.push(ServerEvents.callAnswered, {'call_id': callId});
    await app.pumpUntilGone(find.text('Calling…'));

    // No media server is configured, so the screen says why there is no
    // picture instead of showing a black rectangle.
    expect(find.textContaining('no picture or sound'), findsOneWidget);
  });

  testWidgets('an incoming call rings wherever the user is, and can be '
      'answered', (tester) async {
    final server = _server();
    final match = _matchWithSam(server);
    final app = await _launch(tester, server);

    // On Discover, not in the chat: a call arrives wherever the user is.
    server.calls.add(
      FakeCall(
        id: 'call-1',
        matchId: match.id,
        mode: 'dating',
        isInitiator: false,
        createdAt: server.now(),
      ),
    );
    server.realtime.push(ServerEvents.callIncoming, {
      'call_id': 'call-1',
      'match_id': match.id,
      'mode': 'dating',
      'from': _sam.compact(server.now()),
    });

    await app.pumpUntilFound(find.byType(CallScreen));
    expect(find.text('Incoming'), findsOneWidget);
    expect(find.text('Video call'), findsOneWidget);
    expect(find.text('Sam'), findsOneWidget);

    // The phone rings while it is ringing, and only then: a caller does not
    // hear their own phone ring at them.
    expect(app.backend.ringtones.playing, isTrue);

    await tester.tap(find.text('Answer'));
    await app.pumpUntilGone(find.text('Incoming'));

    expect(server.calls.single.status, 'active');
    expect(app.backend.ringtones.playing, isFalse);

    // The controls a live call has, each named the same whichever way it is
    // set: the icon and the fill say which way that is.
    expect(find.text('Mute'), findsOneWidget);
    expect(find.text('Speaker'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
  });

  testWidgets('a call going out does not ring this phone', (tester) async {
    final server = _server();
    _matchWithSam(server);
    final app = await _openChat(tester, server);

    await tester.tap(find.byTooltip('Video call'));
    await app.pumpUntilFound(find.byType(CallScreen));

    expect(app.backend.ringtones.playing, isFalse);

    await tester.tap(find.text('End'));
    await app.pumpUntilGone(find.byType(CallScreen));
  });

  testWidgets('declining an incoming call closes it for both', (tester) async {
    final server = _server();
    final match = _matchWithSam(server);
    final app = await _launch(tester, server);

    server.calls.add(
      FakeCall(
        id: 'call-1',
        matchId: match.id,
        mode: 'dating',
        isInitiator: false,
        createdAt: server.now(),
      ),
    );
    server.realtime.push(ServerEvents.callIncoming, {
      'call_id': 'call-1',
      'match_id': match.id,
      'mode': 'dating',
      'from': _sam.compact(server.now()),
    });
    await app.pumpUntilFound(find.byType(CallScreen));

    await tester.tap(find.text('Decline'));
    await app.pumpUntilGone(find.byType(CallScreen));

    expect(server.calls.single.status, 'declined');
  });

  testWidgets('a call nobody answers stops ringing by itself', (tester) async {
    final server = _server();
    _matchWithSam(server);
    final app = await _openChat(tester, server);

    await tester.tap(find.byTooltip('Video call'));
    await app.pumpUntilFound(find.byType(CallScreen));

    // The server writes a call off after a minute; the app agrees rather than
    // ringing on a phone the server has already given up on.
    await tester.pump(ringingTimeout);
    await app.pumpUntilGone(find.byType(CallScreen));

    expect(server.calls.single.status, 'missed');
  });

  testWidgets('ending and reporting from the safety sheet stops the call', (
    tester,
  ) async {
    final server = _server();
    _matchWithSam(server);
    final app = await _openChat(tester, server);

    await tester.tap(find.byTooltip('Video call'));
    await app.pumpUntilFound(find.byType(CallScreen));

    final callId = server.calls.single.id;
    server.calls.single
      ..status = 'active'
      ..answeredAt = server.now();
    server.realtime.push(ServerEvents.callAnswered, {'call_id': callId});
    await app.pumpUntilGone(find.text('Calling…'));

    await tester.tap(find.text('Safety'));
    // The sheet starts animating on the frame after a pump, so it has to be
    // found first and then given time to slide up, or the tap lands under it.
    await app.pumpUntilFound(find.text('End the call and report'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('End the call and report'));
    await app.pumpUntilGone(find.byType(CallScreen));

    expect(server.safetyActions.single.action, 'end_and_report');
    expect(server.calls.single.status, 'ended');
  });

  testWidgets('a closed conversation offers no call button', (tester) async {
    final server = _server();
    // Expired, so it is read-only — and calling is refused for the same
    // reasons messaging is.
    _matchWithSam(server, expiresIn: const Duration(days: -1));
    final app = await _openChat(tester, server);
    await app.pumpUntilFound(
      find.text('This match has expired. Extend it to keep talking.'),
    );

    expect(find.byTooltip('Video call'), findsNothing);
  });
}
