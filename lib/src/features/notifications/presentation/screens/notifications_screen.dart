import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/relative_time.dart';
import '../../../../core/widgets/flow_widgets.dart';
import '../../domain/app_notification.dart';
import '../controllers/notifications_controllers.dart';
import '../notification_opener.dart';

/// The user's notifications, newest first. Opening one marks it read and goes
/// to what it's about.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(notificationsFeedProvider);
    final list = feed.value;
    final hasUnread = list?.items.any((each) => each.isUnread) ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              onMarkAllRead: hasUnread
                  ? () => _markAllRead(context, ref)
                  : null,
            ),
            Expanded(
              child: switch (feed) {
                AsyncValue(value: final list?) => _Feed(
                  notifications: list.items,
                  isLoadingMore: list.isLoadingMore,
                  loadMoreFailed: list.loadMoreFailed,
                ),
                AsyncValue(:final error?) => _Failed(
                  message: error is ApiException
                      ? error.message
                      : 'Something went wrong. Please try again.',
                  onRetry: () => ref.invalidate(notificationsFeedProvider),
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref
        .read(notificationsFeedProvider.notifier)
        .markAllRead();
    if (error == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error)));
  }
}

class _Feed extends ConsumerWidget {
  const _Feed({
    required this.notifications,
    required this.isLoadingMore,
    required this.loadMoreFailed,
  });

  final List<AppNotification> notifications;
  final bool isLoadingMore;
  final bool loadMoreFailed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.read(notificationsFeedProvider.notifier);
    final now = ref.watch(clockProvider)();

    Future<void> refresh() async {
      try {
        await feed.refresh();
      } on Object {
        // The failure shows in place of the list, with a way to try again.
      }
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 400) {
            unawaited(feed.loadMore());
          }
          return false;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          children: [
            if (notifications.isEmpty)
              const _CaughtUp()
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A0C132A),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    children: [
                      for (final (index, notification)
                          in notifications.indexed) ...[
                        _NotificationTile(
                          notification: notification,
                          now: now,
                          onTap: () {
                            feed.opened(notification);
                            unawaited(
                              ref
                                  .read(notificationOpenerProvider)
                                  .open(notification.target),
                            );
                          },
                        ),
                        if (index < notifications.length - 1)
                          const Divider(
                            height: 1,
                            color: AppColors.divider,
                            indent: 76,
                            endIndent: 14,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            if (isLoadingMore)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (loadMoreFailed)
              TextButton(
                onPressed: () => unawaited(feed.loadMore()),
                child: const Text("More didn't load. Try again"),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onMarkAllRead});

  /// `null` while there's nothing unread.
  final VoidCallback? onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final onMarkAllRead = this.onMarkAllRead;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0C132A),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tooltip(
              message: MaterialLocalizations.of(context).backButtonTooltip,
              child: Semantics(
                button: true,
                label: MaterialLocalizations.of(context).backButtonTooltip,
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Matches, messages, plans and updates about your account',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (onMarkAllRead != null)
              TextButton(
                onPressed: onMarkAllRead,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.purple,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Mark all read'),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.now,
    required this.onTap,
  });

  final AppNotification notification;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = notification.isUnread;
    final when = timeAgo(notification.createdAt, now);

    return Semantics(
      button: true,
      label: [
        if (unread) 'Unread',
        notification.title,
        notification.body,
        when,
      ].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: unread
              ? AppColors.purpleChip.withValues(alpha: 0.25)
              : Colors.transparent,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _CategoryIcon(category: notification.category),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      when,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.purple,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.category});

  final NotificationCategory category;

  @override
  Widget build(BuildContext context) {
    final (icon, color, background) = switch (category) {
      NotificationCategory.newMatch => (
        Icons.favorite_rounded,
        AppColors.danger,
        const Color(0xFFFCE7F0),
      ),
      NotificationCategory.newLike => (
        Icons.star_rounded,
        const Color(0xFFD97706),
        const Color(0xFFFEF3C7),
      ),
      NotificationCategory.newMessage => (
        Icons.chat_bubble_rounded,
        AppColors.blue,
        const Color(0xFFDBEAFE),
      ),
      NotificationCategory.planUpdate => (
        Icons.calendar_month_rounded,
        const Color(0xFF10B981),
        const Color(0xFFD1FAE5),
      ),
      NotificationCategory.call => (
        Icons.videocam_rounded,
        AppColors.purple,
        AppColors.purpleSoft,
      ),
      NotificationCategory.safety => (
        Icons.shield_rounded,
        AppColors.danger,
        AppColors.dangerSoft,
      ),
      NotificationCategory.moderation => (
        Icons.verified_user_rounded,
        AppColors.purple,
        AppColors.purpleSoft,
      ),
      NotificationCategory.subscription => (
        Icons.workspace_premium_rounded,
        const Color(0xFFD97706),
        const Color(0xFFFEF3C7),
      ),
      NotificationCategory.system || NotificationCategory.unknown => (
        Icons.notifications_rounded,
        AppColors.textSecondary,
        AppColors.surfaceSoft,
      ),
    };

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: 22, color: color),
    );
  }
}

class _CaughtUp extends StatelessWidget {
  const _CaughtUp();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 32,
            color: AppColors.textMuted,
          ),
          SizedBox(height: 12),
          Text(
            "You're all caught up",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'New matches, messages and plans show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Your notifications didn't load",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            PrimaryActionButton(
              label: 'Try again',
              borderRadius: 999,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
