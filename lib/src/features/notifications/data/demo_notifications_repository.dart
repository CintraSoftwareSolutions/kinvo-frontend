import '../../../core/network/api_error_code.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/cursor_page.dart';
import '../../../core/time/clock.dart';
import '../domain/app_notification.dart';
import 'notifications_repository.dart';

/// Notifications for the demo: a few samples about the demo's matches, kept
/// in memory.
final class DemoNotificationsRepository implements NotificationsRepository {
  DemoNotificationsRepository({required Clock clock}) : _clock = clock {
    final now = clock();
    _notifications.addAll([
      _sample(
        'demo-notification-1',
        NotificationCategory.newMatch,
        'It is a match!',
        'You and Sarah liked each other.',
        const {'match_id': 'sarah', 'conversation_id': 'sarah'},
        now.subtract(const Duration(hours: 2)),
        read: false,
      ),
      _sample(
        'demo-notification-2',
        NotificationCategory.newMessage,
        'Emma',
        'Should we meet tomorrow to work on it?',
        const {'conversation_id': 'emma', 'match_id': 'emma'},
        now.subtract(const Duration(hours: 5)),
        read: false,
      ),
      _sample(
        'demo-notification-3',
        NotificationCategory.planUpdate,
        'Plan confirmed',
        'Coffee with Sarah is on for Saturday.',
        const {},
        now.subtract(const Duration(days: 1)),
      ),
      _sample(
        'demo-notification-4',
        NotificationCategory.newLike,
        'Someone liked you',
        'Open Kinvo to see who it is.',
        const {'mode': 'dating'},
        now.subtract(const Duration(days: 2)),
      ),
      _sample(
        'demo-notification-5',
        NotificationCategory.system,
        'Welcome to Kinvo',
        'Switch on the modes you want to meet people in.',
        const {},
        now.subtract(const Duration(days: 3)),
      ),
    ]);
  }

  final Clock _clock;

  /// Newest first.
  final List<AppNotification> _notifications = [];

  final Map<NotificationCategory, bool> _pushEnabled = {};

  @override
  Future<CursorPage<AppNotification>> fetchNotifications({
    String? cursor,
  }) async {
    return CursorPage(
      items: [..._notifications],
      nextCursor: null,
      hasMore: false,
      limit: _notifications.length,
    );
  }

  @override
  Future<int> fetchUnreadCount() async {
    return _notifications.where((notification) => notification.isUnread).length;
  }

  @override
  Future<void> markRead(String notificationId) async {
    final index = _notifications.indexWhere(
      (each) => each.id == notificationId,
    );
    if (index < 0) {
      throw const ApiErrorException(
        code: ApiErrorCode.notFound,
        message: 'We could not find that.',
        statusCode: 404,
      );
    }
    final notification = _notifications[index];
    if (notification.isUnread) {
      _notifications[index] = notification.readAtTime(_clock());
    }
  }

  @override
  Future<void> markAllRead() async {
    final now = _clock();
    for (final (index, notification) in _notifications.indexed) {
      if (notification.isUnread) {
        _notifications[index] = notification.readAtTime(now);
      }
    }
  }

  @override
  Future<List<NotificationPreference>> fetchPreferences() async {
    return [
      for (final category in NotificationCategory.values)
        if (category != NotificationCategory.unknown)
          NotificationPreference(
            category: category,
            pushEnabled: _pushEnabled[category] ?? true,
          ),
    ];
  }

  @override
  Future<NotificationPreference> updatePreference(
    NotificationCategory category, {
    required bool pushEnabled,
  }) async {
    if (!category.canBeSwitchedOff && !pushEnabled) {
      throw const ApiErrorException(
        code: ApiErrorCode.badRequest,
        message: 'Safety notifications cannot be turned off.',
        statusCode: 400,
      );
    }
    _pushEnabled[category] = pushEnabled;
    return NotificationPreference(category: category, pushEnabled: pushEnabled);
  }

  static AppNotification _sample(
    String id,
    NotificationCategory category,
    String title,
    String body,
    Map<String, Object?> data,
    DateTime createdAt, {
    bool read = true,
  }) {
    return AppNotification(
      id: id,
      category: category,
      title: title,
      body: body,
      data: data,
      readAt: read ? createdAt : null,
      createdAt: createdAt,
    );
  }
}
