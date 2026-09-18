import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

/// The Firebase project this build receives push notifications from.
///
/// Supplied with the other build settings, for example in
/// `env/staging.json`. None of these values is secret: they identify the app
/// to Firebase and ship inside it. A build without them runs with push
/// notifications off.
@immutable
final class PushConfig {
  const PushConfig({
    required this.projectId,
    required this.messagingSenderId,
    this.android,
    this.ios,
  });

  /// Reads the values passed at build time. Returns `null` when none are set.
  ///
  /// Throws [AppConfigException] when only some are, so a half-configured
  /// build fails loudly instead of quietly never receiving a notification.
  static PushConfig? fromEnvironment() {
    return parse(const {
      projectIdKey: String.fromEnvironment(projectIdKey),
      messagingSenderIdKey: String.fromEnvironment(messagingSenderIdKey),
      androidApiKeyKey: String.fromEnvironment(androidApiKeyKey),
      androidAppIdKey: String.fromEnvironment(androidAppIdKey),
      iosApiKeyKey: String.fromEnvironment(iosApiKeyKey),
      iosAppIdKey: String.fromEnvironment(iosAppIdKey),
      iosBundleIdKey: String.fromEnvironment(iosBundleIdKey),
    });
  }

  static const projectIdKey = 'FIREBASE_PROJECT_ID';
  static const messagingSenderIdKey = 'FIREBASE_MESSAGING_SENDER_ID';
  static const androidApiKeyKey = 'FIREBASE_ANDROID_API_KEY';
  static const androidAppIdKey = 'FIREBASE_ANDROID_APP_ID';
  static const iosApiKeyKey = 'FIREBASE_IOS_API_KEY';
  static const iosAppIdKey = 'FIREBASE_IOS_APP_ID';
  static const iosBundleIdKey = 'FIREBASE_IOS_BUNDLE_ID';

  final String projectId;
  final String messagingSenderId;

  /// The Android app registered in the project, if there is one.
  final ({String apiKey, String appId})? android;

  /// The iOS app registered in the project, if there is one.
  final ({String apiKey, String appId, String bundleId})? ios;

  /// Reads [values], keyed as the build settings name them. Returns `null`
  /// when none is set.
  @visibleForTesting
  static PushConfig? parse(Map<String, String> values) {
    String value(String key) => (values[key] ?? '').trim();

    if (values.values.every((each) => each.trim().isEmpty)) return null;

    final projectId = value(projectIdKey);
    final senderId = value(messagingSenderIdKey);
    if (projectId.isEmpty || senderId.isEmpty) {
      throw const AppConfigException(
        '$projectIdKey and $messagingSenderIdKey are both needed for push '
        'notifications.',
      );
    }

    final android = _group(
      [androidApiKeyKey, androidAppIdKey],
      value,
      (read) => (apiKey: read(androidApiKeyKey), appId: read(androidAppIdKey)),
    );
    final ios = _group(
      [iosApiKeyKey, iosAppIdKey, iosBundleIdKey],
      value,
      (read) => (
        apiKey: read(iosApiKeyKey),
        appId: read(iosAppIdKey),
        bundleId: read(iosBundleIdKey),
      ),
    );
    if (android == null && ios == null) {
      throw const AppConfigException(
        'Push notifications need the Android or iOS app settings as well as '
        'the Firebase project.',
      );
    }

    return PushConfig(
      projectId: projectId,
      messagingSenderId: senderId,
      android: android,
      ios: ios,
    );
  }

  /// The settings for one platform's app: all of [keys], or none.
  static T? _group<T>(
    List<String> keys,
    String Function(String key) value,
    T Function(String Function(String key) read) build,
  ) {
    final present = keys.where((key) => value(key).isNotEmpty).length;
    if (present == 0) return null;
    if (present < keys.length) {
      throw AppConfigException(
        'Set all of ${keys.join(', ')} for push notifications, or none.',
      );
    }
    return build(value);
  }

  /// What Firebase needs to start on [platform], or `null` when this build
  /// has no app for it.
  FirebaseOptions? optionsFor(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.android => switch (android) {
        final app? => FirebaseOptions(
          apiKey: app.apiKey,
          appId: app.appId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
        ),
        null => null,
      },
      TargetPlatform.iOS => switch (ios) {
        final app? => FirebaseOptions(
          apiKey: app.apiKey,
          appId: app.appId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          iosBundleId: app.bundleId,
        ),
        null => null,
      },
      _ => null,
    };
  }
}
