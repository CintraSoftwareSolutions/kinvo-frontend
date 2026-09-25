import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../entitlements/entitlements.dart';
import '../time/clock.dart';
import 'ads_platform.dart';

/// Google's consent step, taken once per run of the app — and only for an
/// account that will see ads. Someone who pays is never shown the message.
///
/// Starts the ad SDK as soon as consent allows it, so the first ad is not
/// kept waiting for it.
final adConsentProvider = AsyncNotifierProvider<AdConsentController, AdConsent>(
  AdConsentController.new,
);

class AdConsentController extends AsyncNotifier<AdConsent> {
  AdsPlatform get _platform => ref.read(adsPlatformProvider);

  @override
  Future<AdConsent> build() async {
    final consent = await ref.watch(adsPlatformProvider).gatherConsent();
    if (consent.canRequestAds) await _platform.start();
    return consent;
  }

  /// Lets the person change their answer — the "Ad privacy choices" entry.
  Future<void> showPrivacyOptions() async {
    final consent = await _platform.showPrivacyOptions();
    if (consent.canRequestAds) await _platform.start();
    if (ref.mounted) state = AsyncData(consent);
  }
}

/// Whether ads show, and what the person may change about them.
@immutable
final class AdsState {
  const AdsState({required this.showAds, required this.privacyOptionsRequired});

  static const off = AdsState(showAds: false, privacyOptionsRequired: false);

  /// Whether ads may be shown now: the server says this account sees them,
  /// and Google's consent step says they may be requested.
  final bool showAds;

  /// Whether Settings must offer "Ad privacy choices", as the law requires
  /// wherever consent was asked for.
  final bool privacyOptionsRequired;
}

/// Ads, as spec §7.4 has them: for the free plan only.
///
/// Who sees them is the server's decision — `show_ads` among the account's
/// entitlements — never worked out here from a plan's name. Anything unknown
/// means no ads: while the plan is loading, if it cannot be read,
/// and for anyone signed out.
final adsProvider = Provider<AdsState>((ref) {
  if (!ref.watch(adsPlatformProvider).isAvailable) return AdsState.off;

  final entitled = ref.watch(entitlementsProvider).value?.showAds ?? false;
  if (!entitled) return AdsState.off;

  final consent = ref.watch(adConsentProvider).value ?? AdConsent.undecided;
  return AdsState(
    showAds: consent.canRequestAds,
    privacyOptionsRequired: consent.privacyOptionsRequired,
  );
});

/// When an interstitial may interrupt the deck.
///
/// Numbers a product owner may well want to change, so they are in one place.
/// What is fixed is the shape: only at a natural break between cards, never
/// back to back, and never as the first thing someone sees.
@immutable
final class InterstitialPolicy {
  const InterstitialPolicy({
    this.swipesBetween = 15,
    this.minimumGap = const Duration(minutes: 3),
    this.quietStart = const Duration(minutes: 1),
  });

  /// Swipes since the last interstitial before another may show.
  final int swipesBetween;

  /// The least time between two.
  final Duration minimumGap;

  /// How long after swiping starts before the first may show.
  final Duration quietStart;

  bool allows({
    required int swipesSinceLast,
    required DateTime now,
    required DateTime startedAt,
    DateTime? lastShownAt,
  }) {
    if (swipesSinceLast < swipesBetween) return false;
    if (now.difference(startedAt) < quietStart) return false;
    if (lastShownAt != null && now.difference(lastShownAt) < minimumGap) {
      return false;
    }
    return true;
  }
}

final interstitialPolicyProvider = Provider<InterstitialPolicy>(
  (ref) => const InterstitialPolicy(),
);

/// Interstitials between cards in the deck.
final interstitialAdsProvider =
    NotifierProvider<InterstitialAdsController, void>(
      InterstitialAdsController.new,
    );

class InterstitialAdsController extends Notifier<void> {
  late DateTime _startedAt;
  DateTime? _lastShownAt;
  int _swipes = 0;
  bool _showing = false;

  @override
  void build() {
    _startedAt = ref.read(clockProvider)();

    // Loaded as soon as ads are allowed, so one is ready when it is due
    // rather than loading while someone waits between cards.
    ref.listen(adsProvider, (_, ads) {
      if (ads.showAds) ref.read(adsPlatformProvider).preloadInterstitial();
    }, fireImmediately: true);
  }

  /// A swipe the server recorded. [matched]: it made a match, and that moment
  /// belongs to the match, never to an ad.
  Future<void> swipeCompleted({required bool matched}) async {
    // Counted whether or not ads are decided yet: the first swipes of a
    // session can come before the plan and the consent step have settled,
    // and they are swipes all the same. Whether an ad may SHOW is the
    // question asked below.
    _swipes++;
    if (matched || _showing) return;
    if (!ref.read(adsProvider).showAds) return;

    final now = ref.read(clockProvider)();
    final due = ref
        .read(interstitialPolicyProvider)
        .allows(
          swipesSinceLast: _swipes,
          now: now,
          startedAt: _startedAt,
          lastShownAt: _lastShownAt,
        );
    if (!due) return;

    final platform = ref.read(adsPlatformProvider);
    if (!platform.hasInterstitial) {
      // Due, but none loaded: try again at the next swipe rather than make
      // anyone wait for one.
      platform.preloadInterstitial();
      return;
    }

    _showing = true;
    _swipes = 0;
    _lastShownAt = now;
    try {
      await platform.showInterstitial();
    } finally {
      _showing = false;
      platform.preloadInterstitial();
    }
  }
}
