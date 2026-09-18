import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/core/push/push_messaging.dart';
import 'package:kinvo/src/core/widgets/flow_widgets.dart';
import 'package:kinvo/src/features/chat/presentation/screens/chat_screen.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';
import 'package:kinvo/src/features/plans/presentation/screens/plan_composer_screen.dart';
import 'package:kinvo/src/features/plans/presentation/screens/plan_detail_screen.dart';
import 'package:kinvo/src/features/plans/presentation/screens/plans_screen.dart';
import 'package:kinvo/src/features/plans/presentation/screens/venues_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_kinvo_server.dart';
import '../../helpers/fake_push_messaging.dart';

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

DateTime _tomorrow(FakeKinvoServer server) {
  return server.now().add(const Duration(days: 1));
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

Future<AppHarness> _openPlans(
  WidgetTester tester,
  FakeKinvoServer server,
) async {
  final app = await _launch(tester, server);
  app.router.go(AppRoutes.plans);
  await app.pumpUntilFound(find.byType(PlansScreen));
  await app.pumpUntilLoaded();
  return app;
}

Finder _field(String label) => find.widgetWithText(AppInputCard, label);

/// Waits for a sheet or dialog to finish opening, then taps [finder] in it.
Future<void> _tapWhenOpen(WidgetTester tester, Finder finder) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(finder);
}

/// Scrolls the screen until [finder] shows, then taps it. A long list only
/// builds what's near the screen, so scrolling is what makes it appear.
Future<void> _scrollToAndTap(WidgetTester tester, Finder finder) async {
  final page = find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  );
  await tester.scrollUntilVisible(finder, 150, scrollable: page.first);
  await tester.pump();
  await tester.tap(finder);
}

/// Chooses tomorrow at the pickers' suggested time, 7 PM.
Future<void> _chooseTomorrowEvening(WidgetTester tester) async {
  await _scrollToAndTap(tester, find.text('Choose a day'));
  await _tapWhenOpen(tester, find.text('OK'));
  await tester.pump(const Duration(milliseconds: 500));
  await _scrollToAndTap(tester, find.text('Choose a time'));
  await _tapWhenOpen(tester, find.text('OK'));
  await tester.pump(const Duration(milliseconds: 500));
}

/// Tomorrow at 7 PM on this device, as the pickers choose it.
DateTime _tomorrowEvening(FakeKinvoServer server) {
  final today = server.now().toLocal();
  return DateTime(today.year, today.month, today.day + 1, 19);
}

void main() {
  testWidgets('answers a plan the other person suggested, from the list', (
    tester,
  ) async {
    final server = _server();
    final proposal = server.planFromPerson(
      _matchWithSam(server),
      place: 'Brunch at Dishoom',
      at: _tomorrow(server),
      announce: false,
    );
    final app = await _openPlans(tester, server);

    expect(find.text('No plans yet'), findsOneWidget);
    await tester.tap(find.text('Pending'));
    await app.pumpUntilFound(find.text('Brunch at Dishoom'));
    expect(find.text('With Sam'), findsOneWidget);

    await tester.tap(find.text('Accept'));
    await app.pumpUntilFound(find.text("You're on. It's in Upcoming."));

    expect(proposal.status, 'confirmed');
    await app.pumpUntilGone(find.text('Brunch at Dishoom'));
    await tester.tap(find.text('Upcoming'));
    await app.pumpUntilFound(find.text('Brunch at Dishoom'));
    await app.pumpUntilLoaded();
  });

  testWidgets('a plan suggested while the list is open appears at once', (
    tester,
  ) async {
    final server = _server();
    final match = _matchWithSam(server);
    final app = await _openPlans(tester, server);
    await tester.tap(find.text('Pending'));
    await app.pumpUntilFound(find.text('Nothing waiting'));

    server.planFromPerson(match, place: 'Picnic', at: _tomorrow(server));

    await app.pumpUntilFound(find.text('Picnic'));
    // The tab counts it, and so does the bottom navigation.
    await app.pumpUntilFound(find.text('1'));
    await app.pumpUntilLoaded();
  });

  testWidgets('makes a plan with a match, with a place typed in', (
    tester,
  ) async {
    final server = _server();
    _matchWithSam(server);
    final app = await _openPlans(tester, server);

    await tester.tap(find.byTooltip('New plan'));
    await app.pumpUntilFound(find.byType(PlanComposerScreen));
    await app.pumpUntilLoaded();

    // Nothing chosen yet.
    await _scrollToAndTap(tester, find.text('Send plan'));
    await tester.pump();
    expect(find.text('Choose who the plan is with.'), findsOneWidget);
    expect(find.text('Choose a place, or type one.'), findsOneWidget);
    expect(find.text('Choose a day and a time to send it.'), findsOneWidget);

    await _scrollToAndTap(tester, find.text('Sam'));
    await _scrollToAndTap(tester, find.text('Type a place'));
    await tester.pump();
    await tester.enterText(_field('Place'), 'The ramen bar');
    await tester.enterText(_field('Address (optional)'), '12 King Street');
    await _chooseTomorrowEvening(tester);
    await _scrollToAndTap(tester, find.text('1 hour'));
    await _scrollToAndTap(tester, find.text('Send plan'));

    await app.pumpUntilFound(find.byType(PlanDetailScreen));
    await app.pumpUntilLoaded();
    expect(find.text('Waiting for Sam to answer.'), findsOneWidget);

    final plan = server.plans.single;
    expect(plan.status, 'proposed');
    expect(plan.customLocation, 'The ramen bar');
    expect(plan.customAddress, '12 King Street');
    expect(plan.durationMinutes, 60);
    expect(plan.scheduledAt, _tomorrowEvening(server).toUtc());
  });

  testWidgets('suggests a plan from the conversation, at a place from the '
      'list', (tester) async {
    final server = _server()
      ..venues.add(
        const FakeVenue(
          id: 'v1',
          name: 'Blue Bottle',
          address: '8 Kingly Street',
          // Not suggested for the match's mode, so it's found in the list.
          modes: ['study_buddy'],
        ),
      );
    final match = _matchWithSam(server);
    final app = await _launch(tester, server);
    app.router.go(AppRoutes.chat(match.conversationId));
    await app.pumpUntilFound(find.byType(ChatScreen));
    await app.pumpUntilLoaded();

    await tester.tap(find.byTooltip('Conversation options'));
    await app.pumpUntilFound(find.text('Suggest a plan'));
    await _tapWhenOpen(tester, find.text('Suggest a plan'));
    await app.pumpUntilFound(find.byType(PlanComposerScreen));
    await app.pumpUntilLoaded();
    expect(find.text('Sam'), findsOneWidget);

    await _scrollToAndTap(tester, find.text('Find a place'));
    await app.pumpUntilFound(find.byType(VenuesScreen));
    await app.pumpUntilFound(find.text('Blue Bottle'));
    await tester.tap(find.text('Blue Bottle'));
    await app.pumpUntilGone(find.byType(VenuesScreen));
    expect(find.text('8 Kingly Street'), findsOneWidget);

    await _chooseTomorrowEvening(tester);
    await _scrollToAndTap(tester, find.text('Send plan'));
    await app.pumpUntilFound(find.byType(PlanDetailScreen));
    await app.pumpUntilLoaded();

    expect(server.plans.single.venue?.id, 'v1');
    expect(server.plans.single.match, match);
    // Back to the conversation it started from.
    await tester.tap(find.byTooltip('Back'));
    await app.pumpUntilFound(find.byType(ChatScreen));
    await app.pumpUntilLoaded();
  });

  testWidgets('keeps a plan as a draft, then finishes and sends it', (
    tester,
  ) async {
    final server = _server();
    _matchWithSam(server);
    final app = await _launch(tester, server);
    app.router.go(AppRoutes.planWith('match-p1'));
    await app.pumpUntilFound(find.byType(PlanComposerScreen));
    await app.pumpUntilLoaded();

    await _scrollToAndTap(tester, find.text('Type a place'));
    await tester.pump();
    await tester.enterText(_field('Place'), 'Riverside walk');
    await _scrollToAndTap(tester, find.text('Save as draft'));
    await app.pumpUntilFound(find.byType(PlanDetailScreen));
    await app.pumpUntilLoaded();
    expect(server.plans.single.status, 'draft');
    expect(
      find.text("Only you can see this draft. Send it when it's ready."),
      findsOneWidget,
    );

    // It has no time yet, so it's finished in the editor.
    await _scrollToAndTap(tester, find.text('Edit plan'));
    await app.pumpUntilFound(find.text('Edit plan'));
    await app.pumpUntilLoaded();
    await _chooseTomorrowEvening(tester);
    await _scrollToAndTap(tester, find.text('Send plan'));
    await app.pumpUntilGone(find.byType(PlanComposerScreen));
    await app.pumpUntilFound(find.text('Waiting for Sam to answer.'));

    expect(server.plans.single.status, 'proposed');
    expect(server.plans.single.scheduledAt, _tomorrowEvening(server).toUtc());
  });

  testWidgets('calls a plan off, saying why', (tester) async {
    final server = _server();
    final plan = server.planFromPerson(
      _matchWithSam(server),
      place: 'Cinema',
      at: _tomorrow(server),
      status: 'confirmed',
      announce: false,
    );
    final app = await _launch(tester, server);
    app.router.go(AppRoutes.plan(plan.id));
    await app.pumpUntilFound(find.text('Cinema'));
    await app.pumpUntilLoaded();

    await _scrollToAndTap(tester, find.text('Cancel plan'));
    await app.pumpUntilFound(find.text('Cancel this plan?'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextField), 'Feeling unwell.');
    await tester.tap(find.widgetWithText(TextButton, 'Cancel plan').last);

    await app.pumpUntilFound(find.text("Sam has been told the plan is off."));
    expect(plan.status, 'cancelled');
    expect(plan.cancellationReason, 'Feeling unwell.');
    expect(find.text('Cancelled'), findsOneWidget);
  });

  testWidgets('throws a draft away', (tester) async {
    final server = _server();
    final app = await _openPlans(tester, server);
    server.plans.add(
      FakePlan(
        id: 'plan-draft',
        match: _matchWithSam(server),
        createdByUser: true,
        status: 'draft',
        createdAt: server.now(),
      )..customLocation = 'Maybe the zoo',
    );
    await tester.tap(find.text('Drafts'));
    await app.pumpUntilFound(find.text('Maybe the zoo'));
    await tester.tap(find.text('Maybe the zoo'));
    await app.pumpUntilFound(find.byType(PlanDetailScreen));
    await app.pumpUntilLoaded();

    await _scrollToAndTap(tester, find.text('Delete draft'));
    await app.pumpUntilFound(find.text('Delete this draft?'));
    await _tapWhenOpen(tester, find.text('Delete'));

    await app.pumpUntilGone(find.byType(PlanDetailScreen));
    await app.pumpUntilFound(find.text('No drafts'));
    expect(server.plans, isEmpty);
  });

  testWidgets('a plan notification opens the plan', (tester) async {
    final server = _server();
    final plan = server.planFromPerson(
      _matchWithSam(server),
      place: 'Brunch at Dishoom',
      at: _tomorrow(server),
      announce: false,
    );
    final push = FakePushMessaging();
    final app = await _launch(tester, server, push: push);

    push.tap(
      PushMessage(
        title: 'New plan suggested',
        body: 'Brunch at Dishoom — tap to accept or decline.',
        data: {
          'category': 'plan_update',
          'plan_id': plan.id,
          'match_id': 'match-p1',
        },
      ),
    );

    await app.pumpUntilFound(find.byType(PlanDetailScreen));
    await app.pumpUntilFound(find.text('Sam suggested this plan.'));
    await app.pumpUntilLoaded();
  });

  testWidgets("a plan that's gone says so", (tester) async {
    final server = _server();
    final app = await _launch(tester, server);

    app.router.go(AppRoutes.plan('plan-nowhere'));

    await app.pumpUntilFound(find.text("This plan isn't available"));
    await tester.tap(find.text('Back to plans'));
    await app.pumpUntilFound(find.byType(PlansScreen));
    await app.pumpUntilLoaded();
  });

  testWidgets('the demo has sample plans, offline', (tester) async {
    final app = await pumpKinvoApp(tester);
    await app.pumpUntilFound(find.text('Explore Demo'));
    await tester.tap(find.text('Explore Demo'));
    await app.pumpUntilFound(find.byType(DiscoverScreen));
    await app.pumpUntilLoaded();

    app.router.go(AppRoutes.plans);
    await app.pumpUntilFound(find.text('Blue Bottle Coffee'));
    await tester.tap(find.text('Blue Bottle Coffee'));
    await app.pumpUntilFound(find.text("You're both on."));
    await app.pumpUntilLoaded();

    expect(app.adapter.requests, isEmpty);
  });
}
