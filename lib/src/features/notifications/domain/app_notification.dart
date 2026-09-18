import 'package:flutter/foundation.dart';

import '../../../core/network/api_envelope.dart';
import 'notification_target.dart';

/// What a notification is about. Delivery can be switched off for each,
/// except [safety].
enum NotificationCategory {
  newMatch('new_match'),
  newLike('new_like'),
  newMessage('new_message'),
  planUpdate('plan_update'),
  call('call'),
  safety('safety'),
  moderation('moderation'),
  subscription('subscription'),
  system('system'),

  /// A category added to the server after this version of the app.
  unknown('');

  const NotificationCategory(this.wireValue);

  /// The category's name in the API.
  final String wireValue;

  static NotificationCategory fromWireValue(String value) {
    for (final category in values) {
      if (category != unknown && category.wireValue == value) return category;
    }
    return unknown;
  }

  /// Safety notifications carry emergency alerts and the outcome of reports,
  /// so the server never lets them be switched off.
  bool get canBeSwitchedOff => this != safety;
}

/// A notification in the user's feed.
///
/// Every notification the server sends is kept in the feed, so one whose
/// banner was dismissed can still be found.
@immutable
final class AppNotification {
  const AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.data,
    required this.readAt,
    required this.createdAt,
  });

  /// Reads a notification, as `GET /notifications` lists them and the
  /// `notification:new` event carries one.
  factory AppNotification.fromJson(JsonMap json) {
    if (json case {
      'id': final String id,
      'category': final String category,
      'title': final String title,
      'body': final String body,
      'data': final JsonMap data,
      'read_at': final String? readAt,
      'created_at': final String createdAt,
    } when id.isNotEmpty) {
      final created = DateTime.tryParse(createdAt);
      final read = readAt == null ? null : DateTime.tryParse(readAt);
      if (created != null && (readAt == null || read != null)) {
        return AppNotification(
          id: id,
          category: NotificationCategory.fromWireValue(category),
          title: title,
          body: body,
          data: data,
          readAt: read,
          createdAt: created,
        );
      }
    }
    throw const FormatException(
      'Expected a notification with id, category, title, body, data, read_at '
      'and created_at.',
    );
  }

  final String id;
  final NotificationCategory category;
  final String title;
  final String body;

  /// What it's about, such as the conversation or match, for opening it.
  final JsonMap data;

  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;

  /// Where opening it takes the user.
  NotificationTarget get target => NotificationTarget.of(category, data);

  AppNotification readAtTime(DateTime at) {
    return AppNotification(
      id: id,
      category: category,
      title: title,
      body: body,
      data: data,
      readAt: at,
      createdAt: createdAt,
    );
  }
}

/// How one category of notification reaches the user.
@immutable
final class NotificationPreference {
  const NotificationPreference({
    required this.category,
    required this.pushEnabled,
  });

  /// Reads one entry of `GET /notifications/preferences`, which
  /// `PATCH /notifications/preferences/{category}` also returns.
  factory NotificationPreference.fromJson(JsonMap json) {
    if (json case {
      'category': final String category,
      'push_enabled': final bool pushEnabled,
    }) {
      return NotificationPreference(
        category: NotificationCategory.fromWireValue(category),
        pushEnabled: pushEnabled,
      );
    }
    throw const FormatException('Expected category and push_enabled.');
  }

  final NotificationCategory category;

  /// Whether they arrive as push notifications. They're kept in the feed
  /// either way.
  final bool pushEnabled;

  NotificationPreference withPush(bool enabled) {
    return NotificationPreference(category: category, pushEnabled: enabled);
  }
}
