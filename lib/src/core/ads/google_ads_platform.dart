import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_units.dart';
import 'ads_platform.dart';

void _log(String message, [Object? error]) {
  developer.log(message, name: 'kinvo.ads', error: error);
}

/// [AdsPlatform] over Google's Mobile Ads SDK and its consent SDK (UMP).
final class GoogleAdsPlatform implements AdsPlatform {
  GoogleAdsPlatform(this._units);

  final AdUnits _units;

  Future<void>? _started;

  InterstitialAd? _interstitial;
  DateTime? _interstitialLoadedAt;
  bool _loadingInterstitial = false;

  /// Google expires a loaded interstitial after an hour, and showing one past
  /// that fails. Replacing it a little early costs one request; showing a
  /// dead one costs the moment it was meant for.
  static const _interstitialShelfLife = Duration(minutes: 50);

  @override
  bool get isAvailable => true;

  @override
  Future<AdConsent> gatherConsent() async {
    final updated = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      // Everyone here is an adult: the date of birth is checked at sign-up.
      ConsentRequestParameters(tagForUnderAgeOfConsent: false),
      updated.complete,
      (error) {
        // The answer given last time still stands, and canRequestAds below
        // reads it, so a failed update is not a reason to stop.
        _log('Could not update consent information: ${error.message}');
        updated.complete();
      },
    );
    await updated.future;

    // Shows Google's message only where the law requires one and it has not
    // been answered yet; returns straight away everywhere else.
    await ConsentForm.loadAndShowConsentFormIfRequired((error) {
      if (error != null) _log('The consent message failed: ${error.message}');
    });

    return _consent();
  }

  Future<AdConsent> _consent() async {
    final canRequestAds = await ConsentInformation.instance.canRequestAds();
    final privacy = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    return AdConsent(
      canRequestAds: canRequestAds,
      privacyOptionsRequired:
          privacy == PrivacyOptionsRequirementStatus.required,
    );
  }

  @override
  Future<void> start() async {
    if (_started case final started?) return started;

    final starting = _start();
    _started = starting;
    try {
      await starting;
    } on Object catch (error) {
      // Tried again the next time ads are wanted. Nothing else waits on it:
      // an ad that cannot load simply takes no room.
      _started = null;
      _log('The ad SDK did not start.', error);
    }
  }

  Future<void> _start() async {
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        // Kinvo is for adults, but it is a dating app with a cuddle mode:
        // nothing past a teen rating, so no ad embarrasses the screen it is on
        // or the person holding the phone.
        maxAdContentRating: MaxAdContentRating.t,
        // Adults only — the date of birth is checked at sign-up — so no child
        // or teen treatment.
        ageRestrictedTreatment: AgeRestrictedTreatment.unspecified,
      ),
    );
    await MobileAds.instance.initialize();
  }

  @override
  Future<AdConsent> showPrivacyOptions() async {
    await ConsentForm.showPrivacyOptionsForm((error) {
      if (error != null) _log('The privacy options failed: ${error.message}');
    });
    return _consent();
  }

  @override
  Widget buildBanner({required double width, required BannerFrame frame}) {
    return _GoogleBanner(unitId: _units.banner, width: width, frame: frame);
  }

  @override
  void preloadInterstitial() {
    if (_loadingInterstitial) return;
    if (_interstitial != null && !_isStale) return;

    _discardInterstitial();
    _loadingInterstitial = true;
    unawaited(
      InterstitialAd.load(
        adUnitId: _units.interstitial,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _loadingInterstitial = false;
            _interstitial = ad;
            _interstitialLoadedAt = DateTime.now();
          },
          onAdFailedToLoad: (error) {
            _loadingInterstitial = false;
            _log('No interstitial loaded: ${error.message}');
          },
        ),
      ),
    );
  }

  bool get _isStale {
    final loadedAt = _interstitialLoadedAt;
    return loadedAt == null ||
        DateTime.now().difference(loadedAt) > _interstitialShelfLife;
  }

  void _discardInterstitial() {
    unawaited(_interstitial?.dispose());
    _interstitial = null;
    _interstitialLoadedAt = null;
  }

  @override
  bool get hasInterstitial => _interstitial != null && !_isStale;

  @override
  Future<bool> showInterstitial() async {
    if (!hasInterstitial) return false;
    final ad = _interstitial!;
    _interstitial = null;
    _interstitialLoadedAt = null;

    final closed = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        unawaited(ad.dispose());
        if (!closed.isCompleted) closed.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        unawaited(ad.dispose());
        _log('The interstitial did not show: ${error.message}');
        if (!closed.isCompleted) closed.complete(false);
      },
    );
    await ad.show();
    return closed.future;
  }
}

/// An anchored adaptive banner: as wide as its slot, as tall as Google
/// decides for that width, and no room at all until it has loaded.
class _GoogleBanner extends StatefulWidget {
  const _GoogleBanner({
    required this.unitId,
    required this.width,
    required this.frame,
  });

  final String unitId;
  final double width;
  final BannerFrame frame;

  @override
  State<_GoogleBanner> createState() => _GoogleBannerState();
}

class _GoogleBannerState extends State<_GoogleBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  /// Which load is current. Turning the phone twice quickly starts two; only
  /// the last may put its banner on screen.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(_GoogleBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new width — the phone turned — needs a banner sized for it.
    if (oldWidget.width.truncate() != widget.width.truncate() ||
        oldWidget.unitId != widget.unitId) {
      _dispose();
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final width = widget.width.truncate();
    if (width <= 0) return;

    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (!mounted || size == null || generation != _generation) return;

    final ad = BannerAd(
      adUnitId: widget.unitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted || !identical(ad, _ad)) {
            // Loaded for a width, or a slot, that is gone. Disposing twice is
            // harmless: the SDK ignores an ad it has already let go of.
            unawaited(ad.dispose());
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          _log('No banner loaded: ${error.message}');
          if (identical(ad, _ad)) {
            _ad = null;
            if (mounted) setState(() => _loaded = false);
          }
          unawaited(ad.dispose());
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  void _dispose() {
    unawaited(_ad?.dispose());
    _ad = null;
    _loaded = false;
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();

    return widget.frame(
      SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
