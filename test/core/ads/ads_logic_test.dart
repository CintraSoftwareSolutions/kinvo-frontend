import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/ads/ad_units.dart';
import 'package:kinvo/src/core/ads/ads_controller.dart';
import 'package:kinvo/src/core/ads/ads_platform.dart';
import 'package:kinvo/src/core/entitlements/entitlements.dart';
import 'package:kinvo/src/core/time/clock.dart';

import '../../helpers/fake_ads_platform.dart';

/// The rules behind the ads, without a screen: when an interstitial may
/// interrupt, which ad units a build asks for, and who sees ads at all.
void main() {
  group('InterstitialPolicy', () {
    const policy = InterstitialPolicy();
    final start = DateTime.utc(2026, 9, 24, 10);

    bool allows({
      required int swipes,
      Duration after = const Duration(minutes: 10),
      Duration? sinceLast,
    }) {
      final now = start.add(after);
      return policy.allows(
        swipesSinceLast: swipes,
        now: now,
        startedAt: start,
        lastShownAt: sinceLast == null ? null : now.subtract(sinceLast),
      );
    }

    test('waits for enough swipes', () {
      expect(allows(swipes: 14), isFalse);
      expect(allows(swipes: 15), isTrue);
    });

    test('never interrupts the first minute', () {
      expect(allows(swipes: 40, after: const Duration(seconds: 59)), isFalse);
      expect(allows(swipes: 40, after: const Duration(minutes: 1)), isTrue);
    });

    test('never shows two close together', () {
      expect(
        allows(swipes: 40, sinceLast: const Duration(minutes: 2)),
        isFalse,
      );
      expect(allows(swipes: 40, sinceLast: const Duration(minutes: 3)), isTrue);
    });
  });

  group('InterstitialAdsController', () {
    late DateTime now;
    late FakeAdsPlatform ads;

    ProviderContainer container({bool showAds = true}) {
      final container = ProviderContainer.test(
        overrides: [
          adsPlatformProvider.overrideWithValue(ads),
          adsProvider.overrideWithValue(
            AdsState(showAds: showAds, privacyOptionsRequired: false),
          ),
          clockProvider.overrideWithValue(() => now),
          interstitialPolicyProvider.overrideWithValue(
            const InterstitialPolicy(swipesBetween: 3),
          ),
        ],
      );
      // As the home screen does: listened to, so it is live.
      container.listen(interstitialAdsProvider, (_, _) {});
      return container;
    }

    Future<void> swipe(ProviderContainer container, {bool matched = false}) {
      return container
          .read(interstitialAdsProvider.notifier)
          .swipeCompleted(matched: matched);
    }

    setUp(() {
      now = DateTime.utc(2026, 9, 24, 10);
      ads = FakeAdsPlatform();
    });

    test('loads one as soon as ads are allowed', () {
      container();

      expect(ads.interstitialLoads, 1);
    });

    test('shows one once it is due, and starts counting again', () async {
      final app = container();
      now = now.add(const Duration(minutes: 5));

      await swipe(app);
      await swipe(app);
      expect(ads.interstitialsShown, 0);

      await swipe(app);
      expect(ads.interstitialsShown, 1);

      // Straight after, it is neither due by count nor by time.
      now = now.add(const Duration(minutes: 10));
      await swipe(app);
      expect(ads.interstitialsShown, 1);
    });

    test('keeps the moment of a match for the match', () async {
      final app = container();
      now = now.add(const Duration(minutes: 5));

      await swipe(app);
      await swipe(app);
      await swipe(app, matched: true);
      expect(ads.interstitialsShown, 0);

      // The match still counted, so the next swipe is past due.
      await swipe(app);
      expect(ads.interstitialsShown, 1);
    });

    test('does not make anyone wait for one that has not loaded', () async {
      ads.interstitialReady = false;
      final app = container();
      now = now.add(const Duration(minutes: 5));
      final loadsBefore = ads.interstitialLoads;

      for (var i = 0; i < 3; i++) {
        await swipe(app);
      }

      expect(ads.interstitialsShown, 0);
      // Asked for again, for the next time it is due.
      expect(ads.interstitialLoads, greaterThan(loadsBefore));
    });

    test('never shows one to an account that does not see ads', () async {
      final app = container(showAds: false);
      now = now.add(const Duration(minutes: 5));

      for (var i = 0; i < 10; i++) {
        await swipe(app);
      }

      expect(ads.interstitialsShown, 0);
      expect(ads.interstitialLoads, 0);
    });
  });

  group('AdUnits', () {
    const configured = {
      AdUnits.androidBannerKey: 'ca-app-pub-1111111111111111/1111111111',
      AdUnits.androidInterstitialKey: 'ca-app-pub-1111111111111111/2222222222',
    };

    test('a debug build always asks for test ads', () {
      final units = AdUnits.resolve(
        platform: TargetPlatform.android,
        debug: true,
        configured: configured,
      );

      // Tapping a real ad from a development build is invalid traffic.
      expect(units, same(AdUnits.testAndroid));
      expect(units.areTestUnits, isTrue);
    });

    test('a release build asks for the units it was given', () {
      final units = AdUnits.resolve(
        platform: TargetPlatform.android,
        debug: false,
        configured: configured,
      );

      expect(units.banner, 'ca-app-pub-1111111111111111/1111111111');
      expect(units.interstitial, 'ca-app-pub-1111111111111111/2222222222');
      expect(units.areTestUnits, isFalse);
    });

    test('a release build given nothing asks for test ads', () {
      // Staging: env/staging.json names no units.
      final units = AdUnits.resolve(
        platform: TargetPlatform.iOS,
        debug: false,
        configured: const {AdUnits.iosBannerKey: '  '},
      );

      expect(units.banner, AdUnits.testIos.banner);
      expect(units.interstitial, AdUnits.testIos.interstitial);
    });
  });

  group('Entitlements', () {
    test('shows ads only when the server says so in as many words', () {
      Entitlements read(Object? value) {
        return Entitlements.fromJson({
          'tier': 'free',
          'flags': {'show_ads': value},
          'upgrade_available': true,
        });
      }

      expect(read(true).showAds, isTrue);
      expect(read(false).showAds, isFalse);
      // Anything else is not a yes: an account whose flags cannot be read
      // may be one that paid to be rid of ads.
      expect(read('true').showAds, isFalse);
      expect(read(null).showAds, isFalse);
      expect(Entitlements.unknown.showAds, isFalse);
    });
  });
}
