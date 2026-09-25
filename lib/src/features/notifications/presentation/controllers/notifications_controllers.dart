import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/account_providers.dart';
import '../../../../core/auth/auth_providers.dart';
import '../../../../core/auth/session_status.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/paged_list.dart';
import '../../../../core/push/push_messaging.dart';
import '../../../../core/push/push_providers.dart';
import '../../../../core/realtime/realtime_connection.dart';
import '../../../../core/realtime/realtime_events.dart';
import '../../../../core/realtime/realtime_providers.dart';
import '../../../../core/storage/storage_providers.dart';
import '../../../../core/time/clock.dart';
import '../../../chat/data/live_updates.dart';
import '../../../chat/domain/live_update.dart';
import '../../data/notifications_repository.dart';
import '../../domain/app_notification.dart';

/// Notifications that arrived over the live connection, as they arrive.
Stream<AppNotification> _arrivals(Ref ref) {
  return ref
      .watch(realtimeConnectionProvider)
      .events
      .where((event) => event.name == ServerEvents.notificationNew)
      .expand((event) {
        try {
          return [AppNotification.fromJson(event.data)];
        } on FormatException catch (error) {
          developer.log(
            'Ignored a malformed notification.',
            name: 'kinvo.notifications',
            error: error,
          );
          return const <AppNotification>[];
        }
      });
}

/// The user's notification feed, newest first.
final notificationsFeedProvider =
    AsyncNotifierProvider.autoDispose<
      NotificationsFeedController,
      PagedList<AppNotification>
    >(NotificationsFeedController.new);

class NotificationsFeedController
    extends AsyncNotifier<PagedList<AppNotification>> {
  NotificationsRepository get _repository {
    return ref.read(notificationsRepositoryProvider);
  }

  @override
  Future<PagedList<AppNotification>> build() async {
    final arrivals = _arrivals(ref).listen((notification) {
      _update((list) {
        if (list.items.any((each) => each.id == notification.id)) return list;
        return list.copyWith(items: [notification, ...list.items]);
      });
    });
    ref
      ..onDispose(() => unawaited(arrivals.cancel()))
      ..listen(realtimeStatusProvider, (previous, next) {
        // Anything added while the connection was away never arrived.
        if (next == RealtimeStatus.connected &&
            previous != RealtimeStatus.connected &&
            state.hasValue) {
          ref.invalidateSelf();
        }
      });

    final page = await ref
        .watch(notificationsRepositoryProvider)
        .fetchNotifications();
    return PagedList(
      items: page.items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
  }

  Future<void> loadMore() async {
    final list = state.value;
    final cursor = list?.nextCursor;
    if (list == null || !list.hasMore || list.isLoadingMore || cursor == null) {
      return;
    }

    _update((list) {
      return list.copyWith(isLoadingMore: true, loadMoreFailed: false);
    });
    try {
      final page = await _repository.fetchNotifications(cursor: cursor);
      _update((list) {
        final shown = {for (final each in list.items) each.id};
        return list.copyWith(
          items: [
            ...list.items,
            for (final each in page.items)
              if (!shown.contains(each.id)) each,
          ],
          nextCursor: () => page.nextCursor,
          hasMore: page.hasMore,
          isLoadingMore: false,
        );
      });
    } on ApiException {
      _update((list) {
        return list.copyWith(isLoadingMore: false, loadMoreFailed: true);
      });
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Marks [notification] read as the user opens it.
  void opened(AppNotification notification) {
    if (!notification.isUnread) return;
    final now = ref.read(clockProvider)();
    _update((list) {
      return list.copyWith(
        items: [
          for (final each in list.items)
            each.id == notification.id ? each.readAtTime(now) : each,
        ],
      );
    });
    final unread = ref.read(notificationUnreadCountProvider.notifier);
    unawaited(() async {
      try {
        await _repository.markRead(notification.id);
      } on ApiException {
        // It stays read here; the feed catches up next time it loads.
      }
      await unread.refresh();
    }());
  }

  /// Marks everything read. Returns why it failed, or `null`.
  Future<String?> markAllRead() async {
    final list = state.value;
    if (list == null || list.items.every((each) => !each.isUnread)) return null;

    final unread = ref.read(notificationUnreadCountProvider.notifier);
    try {
      await _repository.markAllRead();
    } on ApiException catch (error) {
      return error.message;
    }
    final now = ref.read(clockProvider)();
    _update((list) {
      return list.copyWith(
        items: [
          for (final each in list.items)
            each.isUnread ? each.readAtTime(now) : each,
        ],
      );
    });
    await unread.refresh();
    return null;
  }

  void _update(
    PagedList<AppNotification> Function(PagedList<AppNotification> list) change,
  ) {
    if (!ref.mounted) return;
    if (state.value case final list?) {
      final changed = change(list);
      if (!identical(changed, list)) state = AsyncData(changed);
    }
  }
}

/// Unread notifications, for the bell on Discover, the More tab's badge, and
/// the number on the app's icon.
final notificationUnreadCountProvider =
    AsyncNotifierProvider<NotificationUnreadCountController, int>(
      NotificationUnreadCountController.new,
    );

class NotificationUnreadCountController extends AsyncNotifier<int> {
  /// How long to wait for a burst of changes to finish before counting again.
  static const settleDelay = Duration(milliseconds: 400);

  Timer? _refreshTimer;

  @override
  Future<int> build() async {
    final signedIn = ref.watch(sessionStatusProvider) is SignedIn;
    final repository = ref.watch(notificationsRepositoryProvider);
    if (!signedIn) return 0;

    final arrivals = _arrivals(ref).listen((_) => _scheduleRefresh());
    // Reading a conversation marks the notifications about it read too.
    final updates = ref.watch(liveUpdatesProvider).stream.listen((update) {
      if (update case ConversationActivity(unreadCount: 0)) _scheduleRefresh();
    });
    ref
      ..onDispose(() {
        unawaited(arrivals.cancel());
        unawaited(updates.cancel());
        _refreshTimer?.cancel();
      })
      ..listen(realtimeStatusProvider, (previous, next) {
        if (next == RealtimeStatus.connected &&
            previous != RealtimeStatus.connected) {
          _scheduleRefresh();
        }
      })
      ..listen(appInForegroundProvider, (_, foreground) {
        if (foreground) _scheduleRefresh();
      });

    // The app icon shows the same count.
    final badge = ref.watch(appIconBadgeProvider);
    listenSelf((previous, next) {
      final count = next.value;
      if (count != null && count != previous?.value) {
        unawaited(badge.show(count));
      }
    });

    return repository.fetchUnreadCount();
  }

  /// Counts again now.
  Future<void> refresh() async {
    _refreshTimer?.cancel();
    if (!ref.mounted) return;
    try {
      final count = await ref
          .read(notificationsRepositoryProvider)
          .fetchUnreadCount();
      if (ref.mounted) state = AsyncData(count);
    } on ApiException {
      // Keeps the last count until the next change.
    }
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(settleDelay, () => unawaited(refresh()));
  }
}

/// Which notifications arrive as pushes, for each category.
final notificationPreferencesProvider =
    AsyncNotifierProvider.autoDispose<
      NotificationPreferencesController,
      List<NotificationPreference>
    >(NotificationPreferencesController.new);

class NotificationPreferencesController
    extends AsyncNotifier<List<NotificationPreference>> {
  @override
  Future<List<NotificationPreference>> build() {
    return ref.watch(notificationsRepositoryProvider).fetchPreferences();
  }

  /// Turns pushes for [category] on or off, showing the change at once.
  /// Returns why it failed, having put it back, or `null`.
  Future<String?> setPush(NotificationCategory category, bool enabled) async {
    final preferences = state.value;
    if (preferences == null) return null;
    if (!category.canBeSwitchedOff && !enabled) {
      return "Safety notifications can't be turned off.";
    }

    List<NotificationPreference> withPush(bool value) {
      return [
        for (final each in state.value ?? preferences)
          each.category == category ? each.withPush(value) : each,
      ];
    }

    state = AsyncData(withPush(enabled));
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .updatePreference(category, pushEnabled: enabled);
      return null;
    } on ApiException catch (error) {
      if (ref.mounted) state = AsyncData(withPush(!enabled));
      return error.message;
    }
  }
}

/// Whether this device lets Kinvo show notifications.
final pushPermissionProvider =
    AsyncNotifierProvider.autoDispose<PushPermissionController, PushPermission>(
      PushPermissionController.new,
    );

class PushPermissionController extends AsyncNotifier<PushPermission> {
  @override
  Future<PushPermission> build() {
    // Notifications can be switched on or off in the phone's settings while
    // the app is in the background.
    ref.listen(appInForegroundProvider, (_, foreground) {
      if (foreground) ref.invalidateSelf();
    });
    return ref.watch(pushMessagingProvider).permission();
  }

  /// Shows the system prompt, when the system still will, and registers this
  /// device if the user allows notifications. Returns the answer, or `null`
  /// when the device couldn't be asked.
  ///
  /// Works without anything listening, as when the invitation asks.
  Future<PushPermission?> request() async {
    // Read up front: the prompt can outlast this controller.
    final messaging = ref.read(pushMessagingProvider);
    final registrar = ref.read(pushTokenRegistrarProvider);

    final PushPermission permission;
    try {
      permission = await messaging.requestPermission();
    } on Object catch (error, stackTrace) {
      developer.log(
        'Could not ask to show notifications.',
        name: 'kinvo.notifications',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
    if (permission == PushPermission.granted) unawaited(registrar.sync());
    if (ref.mounted) state = AsyncData(permission);
    return permission;
  }
}

/// Whether to invite the user to turn notifications on: once, on a device
/// where they aren't on and can be asked about, for an account that has
/// finished setting up.
final pushInvitationProvider =
    AsyncNotifierProvider.autoDispose<PushInvitationController, bool>(
      PushInvitationController.new,
    );

class PushInvitationController extends AsyncNotifier<bool> {
  static const _offeredKey = 'kinvo.push_invitation_offered';

  @override
  Future<bool> build() async {
    final messaging = ref.watch(pushMessagingProvider);
    final signedIn = ref.watch(sessionStatusProvider) is SignedIn;
    final onboarded =
        ref.watch(currentAccountProvider).value?.isOnboarded ?? false;
    if (!messaging.isAvailable || !signedIn || !onboarded) return false;

    final store = ref.watch(preferencesKeyValueStoreProvider);
    if (await store.read(_offeredKey) != null) return false;
    return await messaging.permission() == PushPermission.requestable;
  }

  /// Records that the invitation was shown, whatever the answer.
  Future<void> offered() async {
    state = const AsyncData(false);
    try {
      await ref
          .read(preferencesKeyValueStoreProvider)
          .write(_offeredKey, 'true');
    } on Object catch (error, stackTrace) {
      developer.log(
        'Could not remember the notifications invitation.',
        name: 'kinvo.notifications',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
