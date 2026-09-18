import 'package:flutter/foundation.dart';

/// A phone or tablet signed in to the account, from `GET /devices`.
@immutable
final class SignedInDevice {
  const SignedInDevice({
    required this.id,
    required this.platform,
    required this.isCurrent,
    required this.lastSeenAt,
    this.model,
    this.osVersion,
    this.appVersion,
  });

  static SignedInDevice? tryFromJson(Object? json) {
    if (json case {
      'id': final String id,
      'platform': final String platform,
      'app_version': final String? appVersion,
      'os_version': final String? osVersion,
      'model': final String? model,
      'is_current': final bool isCurrent,
      'last_seen_at': final String lastSeenAt,
    } when id.isNotEmpty) {
      if (DateTime.tryParse(lastSeenAt) case final lastSeen?) {
        return SignedInDevice(
          id: id,
          platform: platform,
          isCurrent: isCurrent,
          lastSeenAt: lastSeen,
          model: _filled(model),
          osVersion: _filled(osVersion),
          appVersion: _filled(appVersion),
        );
      }
    }
    return null;
  }

  /// The device's entry in the list, which signing it out removes. Not the
  /// id the app sends as `X-Device-Id`.
  final String id;

  /// `ios`, `android` or `web`.
  final String platform;

  /// Whether it's the device this app is running on.
  final bool isCurrent;

  /// When it last signed in or refreshed its session.
  final DateTime lastSeenAt;

  /// Such as "Google Pixel 8", when the app sent it.
  final String? model;

  /// Such as "Android 15", when the app sent it.
  final String? osVersion;

  /// The version of Kinvo on it, such as `1.0.0+1`.
  final String? appVersion;

  /// What to call it: its model when known, otherwise what kind it is.
  String get name {
    if (model case final model?) return model;
    return switch (platform) {
      'ios' => 'iPhone or iPad',
      'android' => 'Android device',
      _ => 'Web browser',
    };
  }

  static String? _filled(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
