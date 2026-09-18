import 'dart:developer' as developer;

import 'package:app_badge_plus/app_badge_plus.dart';

/// The number on the app's icon.
///
/// The server sets it on iPhone with every push, but only the app can lower
/// it once notifications are read.
abstract interface class AppIconBadge {
  Future<void> show(int count);
}

/// [AppIconBadge] on iPhone. Android shows a dot for unread notifications by
/// itself, so there's nothing to keep in step there.
final class IosAppIconBadge implements AppIconBadge {
  const IosAppIconBadge();

  @override
  Future<void> show(int count) async {
    try {
      await AppBadgePlus.updateBadge(count);
    } on Object catch (error, stackTrace) {
      developer.log(
        'Could not update the app icon badge.',
        name: 'kinvo.push',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

/// [AppIconBadge] where the app doesn't set one.
final class NoAppIconBadge implements AppIconBadge {
  const NoAppIconBadge();

  @override
  Future<void> show(int count) async {}
}
