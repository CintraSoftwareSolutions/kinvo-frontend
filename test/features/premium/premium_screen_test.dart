import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/core/realtime/realtime_events.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';
import 'package:kinvo/src/features/more/presentation/screens/more_screen.dart';
import 'package:kinvo/src/features/premium/presentation/screens/premium_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_kinvo_server.dart';

/// Buying a plan, as staging does it until RevenueCat: a test purchase that
/// starts the plan at once with no money taken.
///
/// What the screen shows is the server's — the prices, what each plan
/// includes, whether buying is possible here — so every assertion about
/// words on screen below is also an assertion that nothing was typed into the
/// app instead.
FakeKinvoServer _server() {
  return FakeKinvoServer()
    ..completeProfile()
    ..isOnboarded = true;
}

/// A live test plan, as a purchase earlier on this or another phone left it.
FakeSubscription _testPlan(
  FakeKinvoServer server, {
  String slug = 'advanced_yearly',
}) {
  final start = server.now().toUtc();
  final (tier, cycle) = switch (slug) {
    'basic_monthly' => ('basic', 'monthly'),
    'basic_yearly' => ('basic', 'yearly'),
    'advanced_monthly' => ('advanced', 'monthly'),
    _ => ('advanced', 'yearly'),
  };
  return FakeSubscription(
    productSlug: slug,
    tier: tier,
    cycle: cycle,
    source: 'test',
    periodStart: start,
    periodEnd: DateTime.utc(
      start.year + (cycle == 'yearly' ? 1 : 0),
      start.month + (cycle == 'monthly' ? 1 : 0),
      start.day,
      start.hour,
    ),
  );
}

Future<AppHarness> _open(
  WidgetTester tester,
  FakeKinvoServer server, {
  String route = AppRoutes.premium,
}) async {
  final app = await pumpKinvoApp(
    tester,
    savedSession: liveSession(),
    respond: server.respond,
    realtime: server.realtime,
    clock: server.now,
  );
  await app.pumpUntilFound(find.byType(DiscoverScreen));
  await app.pumpUntilLoaded();

  app.router.go(route);
  await app.pumpUntilLoaded();
  return app;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  testWidgets('the plans and prices are the server\'s, and it starts free', (
    tester,
  ) async {
    final server = _server();
    final app = await _open(tester, server);
    await app.pumpUntilFound(find.byType(PremiumScreen));

    // Premium, yearly: where someone on the free plan starts.
    expect(find.text('KINVO PREMIUM'), findsOneWidget);
    expect(find.text(r'$159.99'), findsOneWidget);
    expect(find.text(r'$19.99'), findsOneWidget);
    expect(find.text(r'a year · $13.33 a month'), findsOneWidget);
    // Worked out from the two prices, not claimed.
    expect(find.text('Save 33%'), findsOneWidget);
    expect(find.text('See who liked you'), findsOneWidget);
    expect(find.text('Upgrade to Premium'), findsOneWidget);
    expect(find.textContaining('no money is taken'), findsOneWidget);
    expect(find.text('YOUR PLAN'), findsNothing);

    await _tap(tester, find.text('Basic'));

    expect(find.text('KINVO BASIC'), findsOneWidget);
    expect(find.text(r'$79.99'), findsOneWidget);
    expect(find.text(r'$9.99'), findsOneWidget);
    // Basic does not include it, so it is not sold with Basic.
    expect(find.text('See who liked you'), findsNothing);
    expect(find.text('Upgrade to Basic'), findsOneWidget);
  });

  testWidgets('upgrading starts the plan at once, and says until when', (
    tester,
  ) async {
    final server = _server();
    final app = await _open(tester, server);
    await app.pumpUntilFound(find.byType(PremiumScreen));

    await _tap(tester, find.text('Upgrade to Premium'));
    await app.pumpUntilFound(find.text('YOUR PLAN'));

    expect(server.testPurchases, ['advanced_yearly']);
    expect(find.text('Premium · Yearly'), findsOneWidget);
    expect(find.text('Test plan — no money was taken.'), findsOneWidget);
    expect(find.textContaining("You're on Premium until"), findsOneWidget);
    // Nothing left to buy on this plan: the button says so and does nothing.
    expect(find.text('Your current plan'), findsOneWidget);
    expect(find.text('Current plan'), findsOneWidget);

    await _tap(tester, find.text('Your current plan'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(server.testPurchases, hasLength(1));
    await app.pumpUntilLoaded();
  });

  testWidgets('switching down to Basic replaces the plan', (tester) async {
    final server = _server();
    server.subscription = _testPlan(server);
    final app = await _open(tester, server);
    await app.pumpUntilFound(find.text('Premium · Yearly'));

    await _tap(tester, find.text('Basic'));
    expect(find.text('Switch to Basic'), findsOneWidget);

    await _tap(tester, find.text('Switch to Basic'));
    await app.pumpUntilFound(find.text('Basic · Yearly'));

    expect(server.testPurchases, ['basic_yearly']);
    expect(find.text('Premium · Yearly'), findsNothing);
    await app.pumpUntilLoaded();
  });

  testWidgets('a test plan can be ended, back to the free plan', (
    tester,
  ) async {
    final server = _server();
    server.subscription = _testPlan(server, slug: 'advanced_monthly');
    final app = await _open(tester, server);
    await app.pumpUntilFound(find.text('Premium · Monthly'));

    await _tap(tester, find.text('End test plan'));
    await app.pumpUntilFound(find.text('End your test plan?'));

    // Changing your mind leaves it alone.
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();
    expect(server.testPlansEnded, 0);

    await _tap(tester, find.text('End test plan'));
    await app.pumpUntilFound(find.text('End it'));
    await tester.tap(find.text('End it'));
    await app.pumpUntil(
      () => server.testPlansEnded == 1,
      reason: 'the test plan is ended',
    );
    await app.pumpUntilGone(find.text('YOUR PLAN'));

    expect(find.textContaining('Your test plan has ended'), findsOneWidget);
    expect(find.text('Upgrade to Premium'), findsOneWidget);
    await app.pumpUntilLoaded();
  });

  testWidgets('where buying is off, the plans show and nothing can be bought', (
    tester,
  ) async {
    final server = _server()..purchaseMode = 'none';
    final app = await _open(tester, server);
    await app.pumpUntilFound(find.byType(PremiumScreen));

    expect(find.text(r'$159.99'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.textContaining("Buying isn't available"), findsOneWidget);

    await _tap(tester, find.text('Coming soon'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(server.testPurchases, isEmpty);
    await app.pumpUntilLoaded();
  });

  testWidgets('a refused purchase is explained and changes nothing', (
    tester,
  ) async {
    final server = _server();
    server.intercept = (options) async {
      if (options.uri.path.endsWith('/subscriptions/test-purchase')) {
        return jsonResponse(
          400,
          errorEnvelope(
            'VALIDATION_FAILED',
            'Some fields need attention.',
            details: {
              'product': ['That plan is not on sale.'],
            },
          ),
        );
      }
      return null;
    };
    final app = await _open(tester, server);
    await app.pumpUntilFound(find.byType(PremiumScreen));

    await _tap(tester, find.text('Upgrade to Premium'));
    await app.pumpUntilFound(find.text('That plan is not on sale.'));

    expect(find.text('YOUR PLAN'), findsNothing);
    // Still there to try again, or to pick something else.
    expect(find.text('Upgrade to Premium'), findsOneWidget);
    await app.pumpUntilLoaded();
  });

  testWidgets('a plan bought on another phone shows here straight away', (
    tester,
  ) async {
    final server = _server();
    final app = await _open(tester, server);
    await app.pumpUntilFound(find.byType(PremiumScreen));
    expect(find.text('YOUR PLAN'), findsNothing);

    // The server announces a changed plan to every phone the account is on.
    server.subscription = _testPlan(server, slug: 'basic_monthly');
    server.realtime.push(ServerEvents.entitlementsUpdated, {'tier': 'basic'});

    await app.pumpUntilFound(find.text('Basic · Monthly'));
    await app.pumpUntilLoaded();
  });

  testWidgets('More shows who you are and your real plan, and follows it', (
    tester,
  ) async {
    final server = _server();
    final app = await _open(tester, server, route: AppRoutes.more);
    await app.pumpUntilFound(find.byType(MoreScreen));
    await app.pumpUntilFound(find.text('Sam Taylor'));

    // Not the prototype's "Premium member" for everybody.
    expect(find.text('Free plan'), findsOneWidget);
    expect(find.text('Upgrade to Premium'), findsOneWidget);

    await _tap(tester, find.text('Upgrade to Premium'));
    await app.pumpUntilFound(find.byType(PremiumScreen));
    // The tile's words are still underneath, offstage; the screen's own button
    // arrives with the plans.
    await app.pumpUntilFound(find.text('KINVO PREMIUM'));
    await _tap(tester, find.text('Upgrade to Premium'));
    await app.pumpUntilFound(find.text('YOUR PLAN'));

    app.router.go(AppRoutes.more);
    await app.pumpUntilFound(find.text('Premium member'));
    expect(find.text('Your plan: Premium'), findsOneWidget);
    await app.pumpUntilLoaded();
  });
}
