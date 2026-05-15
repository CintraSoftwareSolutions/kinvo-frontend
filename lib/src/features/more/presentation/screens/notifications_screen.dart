import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_colors.dart';

enum NotificationKind { match, message, dateConfirmed, verification, premium }

class NotificationEntry {
  const NotificationEntry({
    required this.title,
    required this.body,
    required this.timeAgo,
    required this.avatar,
    required this.kind,
    required this.unread,
  });

  final String title;
  final String body;
  final String timeAgo;
  final String avatar;
  final NotificationKind kind;
  final bool unread;

  NotificationEntry markRead() => NotificationEntry(
        title: title,
        body: body,
        timeAgo: timeAgo,
        avatar: avatar,
        kind: kind,
        unread: false,
      );
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<NotificationEntry> _entries = [
    NotificationEntry(
      title: 'New Match!',
      body: 'You and Sarah matched!',
      timeAgo: '2 hours ago',
      avatar: AppAssets.avatarSarah,
      kind: NotificationKind.match,
      unread: true,
    ),
    NotificationEntry(
      title: 'New Message',
      body: 'Emma sent you a message',
      timeAgo: '2 hours ago',
      avatar: AppAssets.avatarEmma,
      kind: NotificationKind.message,
      unread: true,
    ),
    NotificationEntry(
      title: 'Date Confirmed',
      body: 'Sarah confirmed your coffee date',
      timeAgo: '2 hours ago',
      avatar: AppAssets.avatarSarah,
      kind: NotificationKind.dateConfirmed,
      unread: false,
    ),
    NotificationEntry(
      title: 'Verification Approved',
      body: 'Your profile has been verified!',
      timeAgo: '2 hours ago',
      avatar: AppAssets.avatarSarah,
      kind: NotificationKind.verification,
      unread: false,
    ),
    NotificationEntry(
      title: 'Premium Feature',
      body: 'Unlock unlimited swipes with Premium',
      timeAgo: '2 hours ago',
      avatar: AppAssets.avatarSarah,
      kind: NotificationKind.premium,
      unread: false,
    ),
  ];

  void _markAllRead() {
    setState(() {
      for (int i = 0; i < _entries.length; i++) {
        if (_entries[i].unread) {
          _entries[i] = _entries[i].markRead();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(onMarkAllRead: _markAllRead),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                child: Container(
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
                  child: Column(
                    children: [
                      for (int i = 0; i < _entries.length; i++) ...[
                        _NotificationTile(
                          entry: _entries[i],
                          isFirst: i == 0,
                          isLast: i == _entries.length - 1,
                        ),
                        if (i < _entries.length - 1)
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
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onMarkAllRead});

  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 18, 18),
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
            GestureDetector(
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
                      'Unread activity across matches, plans, verification, and premium',
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
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onMarkAllRead,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Mark all read',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.purple,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.entry,
    required this.isFirst,
    required this.isLast,
  });

  final NotificationEntry entry;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final BorderRadius? rowRadius;
    if (isFirst && isLast) {
      rowRadius = BorderRadius.circular(20);
    } else if (isFirst) {
      rowRadius = const BorderRadius.vertical(top: Radius.circular(20));
    } else if (isLast) {
      rowRadius = const BorderRadius.vertical(bottom: Radius.circular(20));
    } else {
      rowRadius = null;
    }

    return Container(
      decoration: BoxDecoration(
        color: entry.unread
            ? AppColors.purpleChip.withValues(alpha: 0.25)
            : Colors.transparent,
        borderRadius: rowRadius,
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _AvatarWithBadge(avatar: entry.avatar, kind: entry.kind),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.body,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.timeAgo,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (entry.unread)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.purple,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarWithBadge extends StatelessWidget {
  const _AvatarWithBadge({required this.avatar, required this.kind});

  final String avatar;
  final NotificationKind kind;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Image.asset(
              avatar,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 48,
                height: 48,
                color: AppColors.purpleSoft,
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: _KindBadge(kind: kind),
          ),
        ],
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});

  final NotificationKind kind;

  @override
  Widget build(BuildContext context) {
    final cfg = _config(kind);
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: cfg.bg,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(child: cfg.child),
    );
  }

  _BadgeConfig _config(NotificationKind k) {
    switch (k) {
      case NotificationKind.match:
        return _BadgeConfig(
          bg: const Color(0xFFFCE7F0),
          child: const Icon(
            Icons.favorite_rounded,
            size: 11,
            color: Color(0xFFEF4458),
          ),
        );
      case NotificationKind.message:
        return _BadgeConfig(
          bg: const Color(0xFFDBEAFE),
          child: const Icon(
            Icons.chat_bubble_rounded,
            size: 10,
            color: Color(0xFF3B82F6),
          ),
        );
      case NotificationKind.dateConfirmed:
        return _BadgeConfig(
          bg: const Color(0xFFD1FAE5),
          child: const Icon(
            Icons.calendar_month_rounded,
            size: 11,
            color: Color(0xFF10B981),
          ),
        );
      case NotificationKind.verification:
        return _BadgeConfig(
          bg: const Color(0xFFEDE9FE),
          child: SvgPicture.asset(
            AppAssets.shield,
            width: 10,
            height: 10,
            colorFilter: const ColorFilter.mode(
              AppColors.purple,
              BlendMode.srcIn,
            ),
          ),
        );
      case NotificationKind.premium:
        return _BadgeConfig(
          bg: const Color(0xFFFEF3C7),
          child: const Icon(
            Icons.workspace_premium_rounded,
            size: 12,
            color: Color(0xFFD97706),
          ),
        );
    }
  }
}

class _BadgeConfig {
  const _BadgeConfig({required this.bg, required this.child});
  final Color bg;
  final Widget child;
}
