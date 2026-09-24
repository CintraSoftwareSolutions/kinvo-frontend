import 'package:flutter/widgets.dart';
import 'package:kinvo/src/core/ads/ads_platform.dart';

/// Google's ad SDK, as a test can drive it: it says what it was asked to do,
/// and shows a plain box where a real banner would load.
final class FakeAdsPlatform implements AdsPlatform {
  FakeAdsPlatform({
    this.consent = const AdConsent(
      canRequestAds: true,
      privacyOptionsRequired: false,
    ),
    this.interstitialReady = true,
  });

  /// What a banner looks like here, to find it by.
  static const bannerKey = ValueKey('test-banner');

  /// What Google's consent step decides.
  AdConsent consent;

  /// What the privacy options change the answer to, if anything.
  AdConsent? consentAfterPrivacyOptions;

  /// Whether an interstitial has loaded.
  bool interstitialReady;

  int consentRequests = 0;
  int starts = 0;
  int privacyOptionsShown = 0;
  int interstitialLoads = 0;
  int interstitialsShown = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<AdConsent> gatherConsent() async {
    consentRequests++;
    return consent;
  }

  @override
  Future<void> start() async => starts++;

  @override
  Future<AdConsent> showPrivacyOptions() async {
    privacyOptionsShown++;
    return consent = consentAfterPrivacyOptions ?? consent;
  }

  @override
  Widget buildBanner({required double width, required BannerFrame frame}) {
    return frame(SizedBox(key: bannerKey, width: width, height: 50));
  }

  @override
  void preloadInterstitial() => interstitialLoads++;

  @override
  bool get hasInterstitial => interstitialReady;

  @override
  Future<bool> showInterstitial() async {
    interstitialsShown++;
    return true;
  }
}
