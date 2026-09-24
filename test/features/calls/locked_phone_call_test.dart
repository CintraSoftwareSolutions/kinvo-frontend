import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/features/calls/presentation/call_notifications.dart';
import 'package:kinvo/src/features/calls/presentation/screens/call_screen.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';
import 'package:kinvo/src/features/welcome/presentation/welcome_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_call_notifications.dart';
import '../../helpers/fake_kinvo_server.dart';

/// Answering a call on a phone that was asleep.
///
/// The screen that rings on a locked phone is Android's, not Kinvo's, and the
/// app is only started by the answer itself — so the answer happens before
/// there is anything here to hear it. Everything in this file is about the
/// app catching up with something that already happened.
const _sam = FakePerson(id: 'p1', name: 'Sam');

FakeKinvoServer _server() {
  final server = FakeKinvoServer()
    ..completeProfile()
    ..isOnboarded = true;

  server.matches.add(
    FakeMatch(
      id: 'match-p1',
      mode: 'dating',
      person: _sam,
      isSuperLike: false,
      matchedAt: server.now().subtract(const Duration(days: 1)),
      expiresAt: server.now().add(const Duration(days: 10)),
    ),
  );

  return server;
}

/// A call from Sam, ringing unless [status] says otherwise.
FakeCall _ringing(FakeKinvoServer server, {String status = 'ringing'}) {
  final call = FakeCall(
    id: 'call-1',
    matchId: 'match-p1',
    mode: 'dating',
    isInitiator: false,
    createdAt: server.now(),
  )..status = status;
  if (status == 'active') call.answeredAt = server.now();
  server.calls.add(call);
  return call;
}

Future<AppHarness> _launch(
  WidgetTester tester,
  FakeKinvoServer server,
  FakeCallNotifications phone, {
  bool signedIn = true,
}) async {
  final app = await pumpKinvoApp(
    tester,
    savedSession: signedIn ? liveSession() : null,
    respond: server.respond,
    realtime: server.realtime,
    clock: server.now,
    callNotifications: phone,
  );
  addTearDown(phone.close);
  return app;
}

void main() {
  testWidgets('a call answered while the app was closed is picked up', (
    tester,
  ) async {
    final server = _server();
    final call = _ringing(server);
    // The phone was answered before this app existed: no event to hear, only
    // the platform's memory of it.
    final phone = FakeCallNotifications()..accepted = [call.id];

    final app = await _launch(tester, server, phone);
    await app.pumpUntilFound(find.byType(CallScreen));

    expect(server.calls.single.status, 'active');
    expect(app.backend.requestsTo('/calls/${call.id}/answer'), hasLength(1));
    // The phone's own screen stops offering to answer a call that has been.
    expect(phone.connected, [call.id]);
    expect(find.text('Sam'), findsOneWidget);
  });

  testWidgets('it waits for the session before answering', (tester) async {
    final server = _server();
    final call = _ringing(server);
    final phone = FakeCallNotifications()..accepted = [call.id];

    final app = await _launch(tester, server, phone, signedIn: false);
    await app.pumpUntilFound(find.byType(WelcomeScreen));
    await app.pumpUntilLoaded();

    // Nobody is signed in, so there is no call to join — and no request with
    // no account behind it either.
    expect(app.backend.requestsTo('/calls/${call.id}/answer'), isEmpty);
    expect(find.byType(CallScreen), findsNothing);
    // The screen the phone is still showing goes, rather than ringing on.
    expect(phone.hidden, [call.id]);
  });

  testWidgets('a call answered twice is only answered once', (tester) async {
    final server = _server();
    final call = _ringing(server);
    // Both ways of hearing about it at once: the platform remembered it, and
    // the event arrives as well because the app was running after all.
    final phone = FakeCallNotifications()..accepted = [call.id];

    final app = await _launch(tester, server, phone);
    await app.pumpUntilFound(find.byType(CallScreen));

    phone.tap(CallNotificationAction.answer, call.id);
    // Long enough for a second request to have gone out, if one were going
    // to: what is being tested is that nothing happens.
    await tester.pump(const Duration(seconds: 1));

    expect(app.backend.requestsTo('/calls/${call.id}/answer'), hasLength(1));
    expect(find.byType(CallScreen), findsOneWidget);
    await app.pumpUntilLoaded();
  });

  testWidgets('a call already answered is joined, not answered again', (
    tester,
  ) async {
    final server = _server();
    // Answered on the lock screen, and the server heard about it before this
    // app started: answering again is refused, and rightly.
    final call = _ringing(server, status: 'active');
    final phone = FakeCallNotifications()..accepted = [call.id];

    final app = await _launch(tester, server, phone);
    await app.pumpUntilFound(find.byType(CallScreen));

    // Refused, and then joined with a token instead.
    expect(app.backend.requestsTo('/calls/${call.id}/answer'), hasLength(1));
    expect(app.backend.requestsTo('/calls/${call.id}/token'), hasLength(1));
    expect(find.text('Sam'), findsOneWidget);
    expect(phone.hidden, isEmpty);
  });

  testWidgets('a call that is really over is dropped, and its screen with it', (
    tester,
  ) async {
    final server = _server();
    final call = _ringing(server, status: 'ended');
    final phone = FakeCallNotifications()..accepted = [call.id];

    final app = await _launch(tester, server, phone);
    await app.pumpUntilFound(find.byType(DiscoverScreen));
    await app.pumpUntilLoaded();

    expect(find.byType(CallScreen), findsNothing);
    expect(phone.hidden, [call.id]);
  });

  testWidgets('declining on the lock screen tells the server', (tester) async {
    final server = _server();
    final call = _ringing(server);
    final phone = FakeCallNotifications();

    final app = await _launch(tester, server, phone);
    await app.pumpUntilFound(find.byType(DiscoverScreen));
    await app.pumpUntilLoaded();

    phone.tap(CallNotificationAction.decline, call.id);
    await app.pumpUntil(
      () => server.calls.single.status == 'declined',
      reason: 'the call is declined',
    );

    expect(find.byType(CallScreen), findsNothing);
    expect(phone.hidden, [call.id]);
  });

  testWidgets('ending a call does not come back as a second ending', (
    tester,
  ) async {
    final server = _server();
    final call = _ringing(server, status: 'active');
    final phone = FakeCallNotifications()..accepted = [call.id];

    final app = await _launch(tester, server, phone);
    await app.pumpUntilFound(find.byType(CallScreen));

    await tester.tap(find.text('End'));
    await app.pumpUntil(
      () => server.calls.single.status == 'ended',
      reason: 'the call ends',
    );

    // Closing the phone's own screen is an ending too, and it comes back as
    // an event. The call is over; telling the server twice is noise.
    phone.tap(CallNotificationAction.end, call.id);
    await tester.pump(const Duration(seconds: 1));

    expect(app.backend.requestsTo('/calls/${call.id}/end'), hasLength(1));
    await app.pumpUntilLoaded();
  });
}
