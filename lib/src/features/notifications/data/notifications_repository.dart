import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo/demo_mode.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/cursor_page.dart';
import '../../../core/time/clock.dart';
import '../domain/app_notification.dart';
import 'demo_notifications_repository.dart';

/// The user's notification feed and delivery preferences.
///
/// An interface because the demo shows the same screens without an account,
/// on [DemoNotificationsRepository]. Failures are `ApiException`s.
abstract interface class NotificationsRepository {
  /// One page of notifications, newest first.
  Future<CursorPage<AppNotification>> fetchNotifications({String? cursor});

  Future<int> fetchUnreadCount();

  Future<void> markRead(String notificationId);

  Future<void> markAllRead();

  /// Every category, with the server's defaults for any never changed.
  Future<List<NotificationPreference>> fetchPreferences();

  Future<NotificationPreference> updatePreference(
    NotificationCategory category, {
    required bool pushEnabled,
  });
}

/// [NotificationsRepository] on the Kinvo API.
final class ApiNotificationsRepository implements NotificationsRepository {
  const ApiNotificationsRepository(this._api);

  static const pageSize = 30;

  final ApiClient _api;

  @override
  Future<CursorPage<AppNotification>> fetchNotifications({String? cursor}) {
    return _api.getPage(
      '/notifications',
      decodeItem: AppNotification.fromJson,
      cursor: cursor,
      limit: pageSize,
    );
  }

  @override
  Future<int> fetchUnreadCount() {
    return _api.get('/notifications/unread-count', decode: _readCount);
  }

  @override
  Future<void> markRead(String notificationId) {
    return _api.post(
      '/notifications/${Uri.encodeComponent(notificationId)}/read',
      decode: ApiClient.ignoreData,
    );
  }

  @override
  Future<void> markAllRead() {
    return _api.post('/notifications/read-all', decode: ApiClient.ignoreData);
  }

  @override
  Future<List<NotificationPreference>> fetchPreferences() {
    return _api.get('/notifications/preferences', decode: _readPreferences);
  }

  @override
  Future<NotificationPreference> updatePreference(
    NotificationCategory category, {
    required bool pushEnabled,
  }) {
    return _api.patch(
      '/notifications/preferences/${Uri.encodeComponent(category.wireValue)}',
      body: {'push_enabled': pushEnabled},
      decode: NotificationPreference.fromJson,
    );
  }

  static int _readCount(JsonMap json) {
    if (json case {'unread_count': final int count} when count >= 0) {
      return count;
    }
    throw const FormatException('Expected a non-negative unread_count.');
  }

  static List<NotificationPreference> _readPreferences(JsonMap json) {
    if (json case {'preferences': final List<Object?> preferences}) {
      return [
        for (final preference in preferences)
          if (preference is JsonMap)
            NotificationPreference.fromJson(preference),
      ];
    }
    throw const FormatException('Expected a list of preferences.');
  }
}

/// The repository notifications use: the demo's while exploring it, the
/// API's otherwise.
final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  if (ref.watch(demoSessionProvider)) {
    return DemoNotificationsRepository(clock: ref.watch(clockProvider));
  }
  return ApiNotificationsRepository(ref.watch(apiClientProvider));
});
