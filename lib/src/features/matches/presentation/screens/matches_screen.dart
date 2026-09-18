import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/relative_time.dart';
import '../../../../core/widgets/flow_widgets.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/paywall_sheet.dart';
import '../../../discovery/domain/discovery_mode.dart';
import '../../../discovery/domain/swipe.dart';
import '../../../discovery/presentation/controllers/discovery_modes_controller.dart';
import '../../../discovery/presentation/widgets/match_dialog.dart';
import '../../../discovery/presentation/widgets/mode_picker_sheet.dart';
import '../../../discovery/presentation/widgets/profile_sheet.dart';
import '../../../modes/presentation/mode_presentation.dart';
import '../../../profile/domain/user_summary.dart';
import '../../../profile/presentation/widgets/person_photo.dart';
import '../../domain/match_summary.dart';
import '../controllers/matches_controllers.dart';

/// The Matches tab: matches, the likes inbox, and archived matches.
class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(matchesTabProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'Matches',
          subtitle: 'The people you matched with, and who likes you',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: _Tabs(
            selected: tab,
            onChanged: ref.read(matchesTabProvider.notifier).select,
          ),
        ),
        Expanded(
          child: switch (tab) {
            MatchesTab.matches => const _MatchesList(
              key: ValueKey('matches'),
              archived: false,
            ),
            MatchesTab.requests => const _LikesTab(),
            MatchesTab.archived => const _MatchesList(
              key: ValueKey('archived'),
              archived: true,
            ),
          },
        ),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onChanged});

  final MatchesTab selected;
  final ValueChanged<MatchesTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final tab in MatchesTab.values) ...[
          Flexible(
            child: Semantics(
              button: true,
              selected: tab == selected,
              label: _label(tab),
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => onChanged(tab),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: tab == selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: tab == selected
                        ? const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    _label(tab),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: tab == selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: tab == selected
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ],
    );
  }

  static String _label(MatchesTab tab) {
    return switch (tab) {
      MatchesTab.matches => 'Matches',
      MatchesTab.requests => 'Likes you',
      MatchesTab.archived => 'Archived',
    };
  }
}

/// Current or archived matches.
class _MatchesList extends ConsumerWidget {
  const _MatchesList({required this.archived, super.key});

  final bool archived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = matchesListProvider(archived);
    final matches = ref.watch(provider);
    final notifier = ref.read(provider.notifier);

    Future<void> refresh() async {
      try {
        await notifier.refresh();
      } on Object {
        // The failure shows in place of the list, with a way to try again.
      }
    }

    final list = matches.value;
    if (list == null) {
      if (matches.hasError) {
        return _Message(
          title: "Your matches didn't load",
          message: _messageFor(matches.error),
          onRetry: () => ref.invalidate(provider),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 400) notifier.loadMore();
          return false;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          children: [
            if (list.items.isEmpty)
              _Empty(
                icon: archived
                    ? Icons.inventory_2_outlined
                    : Icons.favorite_border_rounded,
                title: archived ? 'Nothing archived' : 'No matches yet',
                message: archived
                    ? 'Conversations you archive show up here.'
                    : 'When someone you like likes you back, they show up '
                          'here.',
              )
            else
              _Card(
                children: [
                  for (final match in list.items)
                    _MatchTile(
                      match: match,
                      onTap: () => _openMatch(context, ref, match),
                    ),
                ],
              ),
            if (list.isLoadingMore)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (list.loadMoreFailed)
              TextButton(
                onPressed: notifier.loadMore,
                child: const Text("More didn't load. Try again"),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMatch(
    BuildContext context,
    WidgetRef ref,
    MatchSummary match,
  ) async {
    if (match.conversationId case final conversationId?) {
      await context.push(AppRoutes.chat(conversationId));
      return;
    }

    // Every match comes with a conversation, so this is only a safety net: the
    // match is still worth seeing, and ending or extending.
    final now = ref.read(clockProvider)();
    final canExtend =
        match.isExpired || match.expiresAt.difference(now) < extendOfferWithin;
    final notifier = ref.read(matchesListProvider(archived).notifier);
    // Taken from the screen, which outlives the sheet: messages about what
    // the sheet did show after it has closed.
    final messenger = ScaffoldMessenger.of(context);
    final localizations = MaterialLocalizations.of(context);

    await showProfileSheet<void>(
      context,
      user: match.user,
      accent: modeColors(match.mode).primary,
      actions: (sheetContext) => Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                final confirmed = await _confirmUnmatch(
                  sheetContext,
                  match.user,
                );
                if (!confirmed) return;
                final error = await notifier.unmatch(match.id);
                if (error != null) {
                  _say(messenger, error);
                  return;
                }
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                _say(messenger, 'You unmatched ${match.user.displayName}.');
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.dangerSoft),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Unmatch'),
            ),
          ),
          if (canExtend) ...[
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () async {
                  final outcome = await notifier.extend(match.id);
                  switch (outcome) {
                    case Extended(match: final extended):
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                      final until = localizations.formatMediumDate(
                        extended.expiresAt.toLocal(),
                      );
                      _say(messenger, 'Extended until $until.');
                    case ExtendNeedsUpgrade(:final paywall):
                      if (sheetContext.mounted) {
                        await showPaywallSheet(sheetContext, paywall);
                      }
                    case ExtendFailed(:final message):
                      _say(messenger, message);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Text('Extend match'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Future<bool> _confirmUnmatch(
    BuildContext context,
    UserSummary user,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Unmatch ${user.displayName}?'),
        content: const Text(
          "You won't be able to message each other, and this can't be "
          'undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Unmatch'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

class _MatchTile extends ConsumerWidget {
  const _MatchTile({required this.match, required this.onTap});

  final MatchSummary match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final modeLabel = ref.watch(modeLabelProvider(match.mode));
    final colors = modeColors(match.mode);
    final user = match.user;

    final preview = match.lastMessagePreview?.trim() ?? '';
    final subtitle = match.isExpired
        ? 'This match has expired'
        : preview.isNotEmpty
        ? preview
        : 'Matched ${timeAgo(match.matchedAt, now)}';
    final left = match.expiresAt.difference(now);
    final trailing = match.isExpired
        ? 'Expired'
        : left < extendOfferWithin
        ? '${left.inDays < 1 ? '<1' : left.inDays}d left'
        : null;

    return Semantics(
      button: true,
      label: [
        user.displayName,
        modeLabel,
        subtitle,
        if (match.unreadCount > 0) '${match.unreadCount} unread',
        ?trailing,
      ].join(', '),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _Avatar(
                user: user,
                color: colors.primary,
                unread: match.unreadCount,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (user.isVerified) ...[
                          const SizedBox(width: 6),
                          SvgPicture.asset(
                            AppAssets.shield,
                            width: 13,
                            height: 13,
                            colorFilter: const ColorFilter.mode(
                              Color(0xFF3B82F6),
                              BlendMode.srcIn,
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.soft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              modeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Text(
                  trailing,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: match.isExpired
                        ? AppColors.textMuted
                        : AppColors.danger,
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

/// The likes inbox for the mode Discover is showing.
class _LikesTab extends ConsumerWidget {
  const _LikesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeDiscoveryModeProvider);
    final modes = ref.watch(discoveryModesProvider).value ?? const [];
    final mode = active.value;

    if (mode == null) {
      if (active.hasError) {
        return _Message(
          title: "Your likes didn't load",
          message: _messageFor(active.error),
          onRetry: () => ref.invalidate(discoveryModesProvider),
        );
      }
      if (active.hasValue) {
        return const _Empty(
          icon: Icons.tune_rounded,
          title: 'No modes switched on',
          message: 'Likes arrive in the modes you use.',
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    final provider = likesInboxProvider(mode.value);
    final inbox = ref.watch(provider);
    final notifier = ref.read(provider.notifier);

    Future<void> refresh() async {
      try {
        await notifier.refresh();
      } on Object {
        // The failure shows in place of the list, with a way to try again.
      }
    }

    final Widget body;
    switch (inbox.value) {
      case LikesLocked(:final paywall, :final waiting):
        body = _LockedLikes(
          modeLabel: mode.label,
          waiting: waiting,
          onUnlock: () => showPaywallSheet(context, paywall),
        );
      case LikesVisible(:final likes) when likes.items.isEmpty:
        body = _Empty(
          icon: Icons.mark_email_read_outlined,
          title: 'No likes waiting',
          message:
              'When someone likes you in ${mode.label}, they show up here '
              'for you to answer.',
        );
      case LikesVisible(:final likes):
        body = _Card(
          children: [
            for (final like in likes.items)
              _LikeTile(
                like: like,
                onTap: () => _openLike(context, ref, mode, like),
              ),
          ],
        );
      case null when inbox.hasError:
        body = _Message(
          title: "Your likes didn't load",
          message: _messageFor(inbox.error),
          onRetry: () => ref.invalidate(provider),
        );
      case null:
        body = const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        );
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 400) notifier.loadMore();
          return false;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          children: [
            _ModeChip(
              mode: mode,
              onTap: modes.length < 2
                  ? null
                  : () async {
                      final picked = await showModePickerSheet(
                        context,
                        modes: modes,
                        activeMode: mode.value,
                      );
                      if (picked != null) {
                        ref
                            .read(selectedDiscoveryModeProvider.notifier)
                            .select(picked.value);
                      }
                    },
            ),
            const SizedBox(height: 12),
            body,
          ],
        ),
      ),
    );
  }

  Future<void> _openLike(
    BuildContext context,
    WidgetRef ref,
    DiscoveryMode mode,
    LikeReceived like,
  ) async {
    final colors = modeColors(mode.value);
    final notifier = ref.read(likesInboxProvider(mode.value).notifier);

    Future<void> answer(BuildContext sheetContext, SwipeAction action) async {
      final outcome = await notifier.answer(like, action);
      if (!sheetContext.mounted) return;
      switch (outcome) {
        case Answered(:final result):
          Navigator.of(sheetContext).pop();
          if (result.match != null && context.mounted) {
            final choice = await showMatchDialog(
              context,
              user: like.user,
              modeLabel: mode.label,
              modeColor: colors.primary,
              modeSoftColor: colors.soft,
            );
            if (choice == MatchDialogChoice.seeMatches) {
              ref.read(matchesTabProvider.notifier).select(MatchesTab.matches);
            }
          }
        case AnswerGone():
          Navigator.of(sheetContext).pop();
        case AnswerNeedsUpgrade(:final paywall):
          await showPaywallSheet(sheetContext, paywall);
        case AnswerFailed(:final message):
          _tell(sheetContext, message);
      }
    }

    await showProfileSheet<void>(
      context,
      user: like.user,
      accent: colors.primary,
      actions: (sheetContext) => Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => answer(sheetContext, SwipeAction.pass),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.divider),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Pass'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () => answer(sheetContext, SwipeAction.like),
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(mode.likeLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.mode, required this.onTap});

  final DiscoveryMode mode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = modeColors(mode.value);
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: onTap != null,
        label: onTap == null
            ? 'Likes in ${mode.label}'
            : 'Likes in ${mode.label}. Change mode',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: colors.soft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'Likes in ${mode.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: colors.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LikeTile extends ConsumerWidget {
  const _LikeTile({required this.like, required this.onTap});

  final LikeReceived like;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final user = like.user;
    final what = like.isSuperLike ? 'Super liked you' : 'Liked you';
    final when = timeAgo(like.likedAt, now);

    return Semantics(
      button: true,
      label: '${user.displayName}, $what $when',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _Avatar(user: user, color: AppColors.purple, unread: 0),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        user.displayName,
                        if (user.age case final age?) '$age',
                      ].join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$what $when',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (like.isSuperLike)
                const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFF59E0B),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LockedLikes extends StatelessWidget {
  const _LockedLikes({
    required this.modeLabel,
    required this.waiting,
    required this.onUnlock,
  });

  final String modeLabel;
  final int? waiting;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final waiting = this.waiting;
    final title = switch (waiting) {
      null => 'See who likes you',
      0 => 'No likes waiting yet',
      1 => '1 person likes you',
      _ => '$waiting people like you',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.purpleSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: AppColors.purple,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Premium shows you who liked you in $modeLabel, so you can like '
            'them back and match straight away.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          PrimaryActionButton(label: 'See who likes you', onPressed: onUnlock),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.user,
    required this.color,
    required this.unread,
  });

  final UserSummary user;
  final Color color;
  final int unread;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: SizedBox(
              width: 52,
              height: 52,
              child: PersonPhoto(
                url: user.photoUrl,
                name: user.displayName,
                color: color,
                initialSize: 22,
              ),
            ),
          ),
          if (unread > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4458),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          if (user.isOnline)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0C132A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (final (index, child) in children.indexed) ...[
            child,
            if (index < children.length - 1)
              const Divider(
                height: 1,
                color: AppColors.divider,
                indent: 78,
                endIndent: 14,
              ),
          ],
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.surfaceSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 26, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
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
              PrimaryActionButton(label: 'Try again', onPressed: onRetry),
            ],
          ),
        ),
      ],
    );
  }
}

String _messageFor(Object? error) {
  return error is ApiException
      ? error.message
      : 'Something went wrong. Please try again.';
}

void _tell(BuildContext context, String message) {
  _say(ScaffoldMessenger.of(context), message);
}

void _say(ScaffoldMessengerState messenger, String message) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
