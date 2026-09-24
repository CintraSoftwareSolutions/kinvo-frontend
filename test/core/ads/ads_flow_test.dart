import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/ads/ads_controller.dart';
import 'package:kinvo/src/core/ads/ads_platform.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/core/realtime/realtime_events.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_ads_platform.dart';
import '../../helpers/fake_kinvo_server.dart';

/// Ads, as spec §7.4 has them: banners and interstitials, for the free plan
/// only.
///
/// Who sees them is the server's answer — `show_ads` among the account's
/// entitlements — so the fake server below decides it from the plan the way
/// the real matrix does, and nothing here tells the app a plan's name.
final _banner = find.byKey(FakeAdsPlatform.bannerKey);

FakeKinvoServer _server() {
  return FakeKinvoServer()
    ..completeProfile()
    ..isOnboarded = true;
}

/// A live plan, as a purchase would leave it.
FakeSubscription _plan(FakeKinvoServer server, String tier) {
  final start = server.now().toUtc();
  return FakeSubscription(
    productSlug: '${tier}_monthly',
    tier: tier,
    cycle: 'monthly',
    source: 'test',
    periodStart: start,
    periodEnd: start.add(const Duration(days: 30)),
  );
}

Future<AppHarness> _open(
  WidgetTester tester,
  FakeKinvoServer server,
  FakeAdsPlatform ads,
) async {
  final app = await pumpKinvoApp(
    tester,
    savedSession: liveSession(),
    respond: server.respond,
    realtime: server.realtime,
    clock: server.now,
    ads: ads,
  );
  await app.pumpUntilFound(find.byType(DiscoverScreen));
  await app.pumpUntilLoaded();
  return app;
}

Future<void> _go(WidgetTester tester, AppHarness app, String route) async {
  app.router.go(route);
  await app.pumpUntilLoaded();
  // A request with no spinner to wait on — what the plan unlocks — still
  // settles before the test moves on.
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('a free account sees banners on Matches, Plans and More only', (
    tester,
  ) async {
    final ads = FakeAdsPlatform();
    final app = await _open(tester, _server(), ads);

    // Never over the deck, where the swipe buttons are.
    expect(_banner, findsNothing);

    for (final (route, shows) in [
      (AppRoutes.matches, true),
      (AppRoutes.plans, true),
      (AppRoutes.profile, false),
      (AppRoutes.more, true),
      (AppRoutes.discover, false),
    ]) {
      await _go(tester, app, route);
      expect(_banner, shows ? findsOneWidget : findsNothing, reason: route);
    }

    // Asked once, however many screens it showed on.
    expect(ads.consentRequests, 1);
    expect(ads.starts, 1);
  });

  testWidgets('nobody who pays sees an ad, or is asked about them', (
    tester,
  ) async {
    final server = _server();
    server.subscription = _plan(server, 'basic');
    final ads = FakeAdsPlatform();
    final app = await _open(tester, server, ads);

    await _go(tester, app, AppRoutes.matches);

    expect(_banner, findsNothing);
    // Google's consent message is for people who will see ads.
    expect(ads.consentRequests, 0);
    expect(ads.starts, 0);
  });

  testWidgets('upgrading takes the ads away at once', (tester) async {
    final server = _server();
    final app = await _open(tester, server, FakeAdsPlatform());
    await _go(tester, app, AppRoutes.matches);
    expect(_banner, findsOneWidget);

    // Bought on this phone or another: the server announces the new plan to
    // every phone the account is on.
    server.subscription = _plan(server, 'advanced');
    server.realtime.push(ServerEvents.entitlementsUpdated, {
      'tier': 'advanced',
    });

    await app.pumpUntilGone(_banner);
    await app.pumpUntilLoaded();
  });

  testWidgets('no ad loads until Google\'s consent step allows it', (
    tester,
  ) async {
    final ads = FakeAdsPlatform(
      consent: const AdConsent(
        canRequestAds: false,
        privacyOptionsRequired: true,
      ),
    );
    final app = await _open(tester, _server(), ads);

    await _go(tester, app, AppRoutes.matches);

    expect(ads.consentRequests, 1);
    expect(_banner, findsNothing);
    // Not even started: the SDK waits for consent too.
    expect(ads.starts, 0);
  });

  testWidgets('ad privacy choices are offered where the law requires them', (
    tester,
  ) async {
    final ads =
        FakeAdsPlatform(
            consent: const AdConsent(
              canRequestAds: true,
              privacyOptionsRequired: true,
            ),
          )
          ..consentAfterPrivacyOptions = const AdConsent(
            canRequestAds: false,
            privacyOptionsRequired: true,
          );
    final app = await _open(tester, _server(), ads);
    await _go(tester, app, AppRoutes.matches);
    expect(_banner, findsOneWidget);

    await _go(tester, app, AppRoutes.settings);
    final choices = find.text('Ad privacy choices');
    await tester.ensureVisible(choices);
    await tester.pump();
    await tester.tap(choices);
    await app.pumpUntil(
      () => ads.privacyOptionsShown == 1,
      reason: 'the privacy options open',
    );

    // Their new answer is the one that counts from now on.
    await _go(tester, app, AppRoutes.matches);
    expect(_banner, findsNothing);
  });

  testWidgets('no privacy choices where nothing requires them', (tester) async {
    final app = await _open(tester, _server(), FakeAdsPlatform());

    await _go(tester, app, AppRoutes.settings);

    expect(find.text('Ad privacy choices'), findsNothing);
  });

  testWidgets('the demo shows no ads and asks nothing', (tester) async {
    final ads = FakeAdsPlatform();
    final app = await pumpKinvoApp(tester, ads: ads);
    await app.pumpUntilFound(find.text('Explore Demo'));
    await tester.tap(find.text('Explore Demo'));
    await app.pumpUntilFound(find.byType(DiscoverScreen));
    await app.pumpUntilLoaded();

    await _go(tester, app, AppRoutes.matches);

    expect(_banner, findsNothing);
    expect(ads.consentRequests, 0);
  });

  testWidgets('an interstitial shows between cards once it is due', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 9, 24, 10);
    final server = _server()
      ..now = (() => now)
      ..decks['dating'] = [
        const FakePerson(id: 'p1', name: 'Ada'),
        const FakePerson(id: 'p2', name: 'Bea'),
        const FakePerson(id: 'p3', name: 'Cat'),
      ];
    final ads = FakeAdsPlatform();
    final app = await pumpKinvoApp(
      tester,
      savedSession: liveSession(),
      respond: server.respond,
      realtime: server.realtime,
      clock: () => now,
      ads: ads,
      // Two swipes rather than fifteen, and no quiet start, so the test is
      // about the wiring; the policy has its own tests.
      overrides: [
        interstitialPolicyProvider.overrideWithValue(
          const InterstitialPolicy(swipesBetween: 2, quietStart: Duration.zero),
        ),
      ],
    );
    await app.pumpUntilFound(find.text('Ada'));
    await app.pumpUntilLoaded();
    // Ready before it can be due: loaded with the home screen.
    await app.pumpUntil(
      () => ads.interstitialLoads > 0,
      reason: 'an interstitial is loading',
    );

    Finder like() => find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == 'Like',
    );
    Future<void> swipe(String next) async {
      await tester.ensureVisible(like());
      await tester.pump();
      await tester.tap(like());
      await app.pumpUntilFound(find.text(next));
      await app.pumpUntilLoaded();
    }

    await swipe('Bea');
    expect(ads.interstitialsShown, 0);

    now = now.add(const Duration(seconds: 30));
    await swipe('Cat');
    expect(ads.interstitialsShown, 1);
  });
}
