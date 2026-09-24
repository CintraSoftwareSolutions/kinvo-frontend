import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ad_units.dart';
import 'google_ads_platform.dart';

/// How a loaded banner is set on the screen — the gap and the line that keep
/// it apart from what is around it. Applied only once there is a banner, so
/// no empty frame ever shows.
typedef BannerFrame = Widget Function(Widget banner);

/// What Google's consent step decided.
@immutable
final class AdConsent {
  const AdConsent({
    required this.canRequestAds,
    required this.privacyOptionsRequired,
  });

  /// Nothing decided yet, or the step failed: no ads may be requested.
  static const undecided = AdConsent(
    canRequestAds: false,
    privacyOptionsRequired: false,
  );

  /// Whether ads may be requested now. False until the person has answered
  /// the consent message wherever the law requires one, as in the UK and the
  /// EEA; true at once where it doesn't.
  final bool canRequestAds;

  /// Whether the law requires a way to change that answer later — the "Ad
  /// privacy choices" entry in Settings.
  final bool privacyOptionsRequired;
}

/// Google's ad SDK, behind an interface.
///
/// Every test runs without it — ads need a real phone and the network — so
/// the app talks to this, and tests supply a fake that says what it was asked
/// to do. The same reason the phone's own call screen and its ringtones sit
/// behind interfaces.
abstract interface class AdsPlatform {
  /// Whether this device can show ads at all: an Android or iOS build.
  bool get isAvailable;

  /// Asks Google whether consent is needed here, shows its message where it
  /// is, and says whether ads may now be requested.
  Future<AdConsent> gatherConsent();

  /// Starts the ad SDK. Called once, after consent allows ads.
  Future<void> start();

  /// Lets the person change their answer, where the law requires that.
  Future<AdConsent> showPrivacyOptions();

  /// A banner [width] wide, set in [frame] once it has loaded. Takes no room
  /// until then, and none at all if one never does.
  Widget buildBanner({required double width, required BannerFrame frame});

  /// Loads the next interstitial in the background, unless one is waiting.
  void preloadInterstitial();

  /// Whether an interstitial has loaded and can be shown at once.
  bool get hasInterstitial;

  /// Shows the waiting interstitial. Completes once it has been closed, with
  /// whether it showed at all.
  Future<bool> showInterstitial();
}

/// For a device with no ads: anything but an Android or iOS build.
final class NoAdsPlatform implements AdsPlatform {
  const NoAdsPlatform();

  @override
  bool get isAvailable => false;

  @override
  Future<AdConsent> gatherConsent() async => AdConsent.undecided;

  @override
  Future<void> start() async {}

  @override
  Future<AdConsent> showPrivacyOptions() async => AdConsent.undecided;

  @override
  Widget buildBanner({required double width, required BannerFrame frame}) {
    return const SizedBox.shrink();
  }

  @override
  void preloadInterstitial() {}

  @override
  bool get hasInterstitial => false;

  @override
  Future<bool> showInterstitial() async => false;
}

final adsPlatformProvider = Provider<AdsPlatform>((ref) {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS when !kIsWeb =>
      GoogleAdsPlatform(AdUnits.fromEnvironment(defaultTargetPlatform)),
    _ => const NoAdsPlatform(),
  };
});
