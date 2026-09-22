import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_router.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/push/push_messaging.dart';
import '../../discovery/presentation/controllers/discovery_modes_controller.dart';
import '../../matches/data/matches_repository.dart';
import '../../matches/presentation/controllers/matches_controllers.dart';
import '../data/notifications_repository.dart';
import '../domain/app_notification.dart';
import '../domain/notification_target.dart';
import 'controllers/notifications_controllers.dart';

final notificationOpenerProvider = Provider<NotificationOpener>(
  NotificationOpener.new,
);

/// Takes the user to what a notification is about, from the notifications
/// list, an in-app banner, or a push they tapped.
final class NotificationOpener {
  NotificationOpener(this._ref);

  /// The tabs' own locations. A screen opened over one of them is pushed, so
  /// back returns to where the user was.
  static const _tabs = [
    AppRoutes.discover,
    AppRoutes.matches,
    AppRoutes.plans,
    AppRoutes.profile,
    AppRoutes.more,
  ];

  final Ref _ref;

  /// Opens the push notification [message], marking it read.
  Future<void> openPush(PushMessage message) {
    final data = message.data;
    final category = NotificationCategory.fromWireValue(data['category'] ?? '');
    return open(
      NotificationTarget.of(category, data),
      notificationId: data['notification_id'],
    );
  }

  /// Opens [target]. With [notificationId], marks that notification read too.
  Future<void> open(NotificationTarget target, {String? notificationId}) async {
    if (notificationId != null && notificationId.isNotEmpty) {
      unawaited(_markRead(notificationId));
    }

    final router = _ref.read(appRouterProvider);
    switch (target) {
      case OpenConversation(:final conversationId):
        _show(router, AppRoutes.chat(conversationId));
      case OpenMatch(:final matchId):
        await _openMatch(router, matchId);
      case OpenMatches():
        _ref.read(matchesTabProvider.notifier).select(MatchesTab.matches);
        router.go(AppRoutes.matches);
      case OpenLikes(:final mode):
        if (mode != null) {
          _ref.read(selectedDiscoveryModeProvider.notifier).select(mode);
        }
        _ref.read(matchesTabProvider.notifier).select(MatchesTab.requests);
        router.go(AppRoutes.matches);
      case OpenPlan(:final planId):
        _show(router, AppRoutes.plan(planId));
      case OpenPlans():
        router.go(AppRoutes.plans);
      case OpenSafety():
        _show(router, AppRoutes.safetyCenter);
      case OpenVerification():
        _show(router, AppRoutes.verificationMethods);
      case OpenNotifications():
        _show(router, AppRoutes.notifications);
    }
  }

  Future<void> _openMatch(GoRouter router, String matchId) async {
    try {
      final match = await _ref
          .read(matchesRepositoryProvider)
          .fetchMatch(matchId);
      if (match.conversationId case final conversationId?) {
        _show(router, AppRoutes.chat(conversationId));
        return;
      }
    } on ApiException {
      // Ended, or unreachable just now: the matches list is the next best
      // place.
    }
    router.go(AppRoutes.matches);
  }

  /// Shows [location] over whatever tab is open, or goes straight to it when
  /// no tab is showing yet, such as while a tapped notification launches the
  /// app.
  void _show(GoRouter router, String location) {
    final current = router.state.uri.path;
    if (current == location) return;
    final inTabs = _tabs.any(
      (tab) => current == tab || current.startsWith('$tab/'),
    );
    if (inTabs) {
      unawaited(router.push<void>(location));
    } else {
      router.go(location);
    }
  }

  Future<void> _markRead(String notificationId) async {
    try {
      await _ref.read(notificationsRepositoryProvider).markRead(notificationId);
    } on ApiException {
      // Stays unread until the list is opened; nothing is lost.
      return;
    }
    await _ref.read(notificationUnreadCountProvider.notifier).refresh();
  }
}
