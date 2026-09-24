import 'package:flutter/foundation.dart';

/// The AdMob ad units this build asks for.
///
/// Google's test units unless the build is given real ones — and the test
/// units in every debug build regardless, because tapping a real ad from a
/// development build is invalid traffic, and AdMob closes accounts for it.
/// Staging's settings (`env/staging.json`) name no units, so staging never
/// shows a real ad either: real ones belong only in the production settings.
@immutable
final class AdUnits {
  const AdUnits({required this.banner, required this.interstitial});

  /// Reads the units passed at build time for [platform], falling back to
  /// Google's test units for anything not given.
  factory AdUnits.fromEnvironment(TargetPlatform platform) {
    return resolve(
      platform: platform,
      debug: kDebugMode,
      configured: const {
        androidBannerKey: String.fromEnvironment(androidBannerKey),
        androidInterstitialKey: String.fromEnvironment(androidInterstitialKey),
        iosBannerKey: String.fromEnvironment(iosBannerKey),
        iosInterstitialKey: String.fromEnvironment(iosInterstitialKey),
      },
    );
  }

  static const androidBannerKey = 'ADMOB_ANDROID_BANNER_ID';
  static const androidInterstitialKey = 'ADMOB_ANDROID_INTERSTITIAL_ID';
  static const iosBannerKey = 'ADMOB_IOS_BANNER_ID';
  static const iosInterstitialKey = 'ADMOB_IOS_INTERSTITIAL_ID';

  /// Google's published test units: they always fill, and never pay.
  static const testAndroid = AdUnits(
    banner: 'ca-app-pub-3940256099942544/9214589741',
    interstitial: 'ca-app-pub-3940256099942544/1033173712',
  );

  static const testIos = AdUnits(
    banner: 'ca-app-pub-3940256099942544/2435281174',
    interstitial: 'ca-app-pub-3940256099942544/4411468910',
  );

  /// Picks the units for [platform] from [configured], by the keys above.
  @visibleForTesting
  static AdUnits resolve({
    required TargetPlatform platform,
    required bool debug,
    required Map<String, String> configured,
  }) {
    final (test, bannerKey, interstitialKey) = switch (platform) {
      TargetPlatform.iOS => (testIos, iosBannerKey, iosInterstitialKey),
      _ => (testAndroid, androidBannerKey, androidInterstitialKey),
    };
    if (debug) return test;

    String pick(String key, String fallback) {
      final value = configured[key]?.trim() ?? '';
      return value.isEmpty ? fallback : value;
    }

    return AdUnits(
      banner: pick(bannerKey, test.banner),
      interstitial: pick(interstitialKey, test.interstitial),
    );
  }

  final String banner;
  final String interstitial;

  /// Whether these are Google's test units, which is right everywhere except a
  /// production build.
  bool get areTestUnits =>
      banner.startsWith('ca-app-pub-3940256099942544/') &&
      interstitial.startsWith('ca-app-pub-3940256099942544/');
}
