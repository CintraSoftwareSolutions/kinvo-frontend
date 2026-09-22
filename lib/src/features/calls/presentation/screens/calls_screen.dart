import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/paged_list.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/relative_time.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../notifications/domain/notification_target.dart';
import '../../../notifications/presentation/notification_opener.dart';
import '../../../profile/presentation/widgets/person_photo.dart';
import '../../domain/call.dart';
import '../controllers/call_controller.dart';
import '../controllers/call_history_controller.dart';

/// Every call, newest first: who it was with, which way it went, and how long
/// it lasted. Calling again from here starts the same kind of call.
class CallsScreen extends ConsumerWidget {
  const CallsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(callHistoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Calls',
              subtitle: 'Your video and voice calls',
              leading: HeaderBackButton(),
            ),
            Expanded(
              child: switch (history) {
                AsyncValue(value: final list?) when list.items.isEmpty =>
                  const _Empty(),
                AsyncValue(value: final list?) => _History(list: list),
                AsyncValue(:final error?) => _Failed(
                  message: error is ApiException
                      ? error.message
                      : 'Something went wrong. Please try again.',
                  onRetry: () => ref.invalidate(callHistoryProvider),
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _History extends ConsumerWidget {
  const _History({required this.list});

  final PagedList<Call> list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();

    return RefreshIndicator(
      onRefresh: ref.read(callHistoryProvider.notifier).refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // Within a screen of the end: the next page is fetched before the
          // list runs out, so scrolling never stops to wait.
          final metrics = notification.metrics;
          if (metrics.pixels > metrics.maxScrollExtent - 600) {
            unawaited(ref.read(callHistoryProvider.notifier).loadMore());
          }
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
          itemCount: list.items.length + (list.hasMore ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index >= list.items.length) {
              return _LoadingMore(failed: list.loadMoreFailed);
            }
            return _CallRow(call: list.items[index], now: now);
          },
        ),
      ),
    );
  }
}

class _CallRow extends ConsumerWidget {
  const _CallRow({required this.call, required this.now});

  final Call call;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missed = call.status == CallStatus.missed && !call.isInitiator;
    final other = call.otherUser;

    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: () => unawaited(_openChat(ref)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: ClipOval(
                  child: PersonPhoto(
                    url: other.photoUrl,
                    name: other.displayName,
                    color: AppColors.purple,
                    initialSize: 40,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      other.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: missed
                            ? AppColors.danger
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          _directionIcon(call),
                          size: 14,
                          color: missed
                              ? AppColors.danger
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            _describe(call, now),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Calls back the same way it was: someone returning a voice call
              // does not expect their camera to come on.
              IconButton(
                tooltip: call.kind == CallKind.audio
                    ? 'Voice call ${other.displayName}'
                    : 'Video call ${other.displayName}',
                icon: Icon(
                  call.kind == CallKind.audio
                      ? Icons.call_rounded
                      : Icons.videocam_rounded,
                  color: AppColors.purple,
                ),
                onPressed: () => unawaited(_callAgain(context, ref)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openChat(WidgetRef ref) {
    // The same route a call notification opens: the match is looked up and its
    // conversation shown, so this list needs to know nothing about either.
    return ref.read(notificationOpenerProvider).open(OpenMatch(call.matchId));
  }

  Future<void> _callAgain(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(callControllerProvider.notifier)
          .start(call.matchId, kind: call.kind);
    } on ApiException catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error is ApiErrorException
                  ? error.message
                  : 'Could not reach Kinvo. Check your connection.',
            ),
          ),
        );
    }
  }

  static IconData _directionIcon(Call call) {
    if (call.status == CallStatus.missed && !call.isInitiator) {
      return Icons.call_missed_rounded;
    }
    return call.isInitiator
        ? Icons.call_made_rounded
        : Icons.call_received_rounded;
  }

  /// One line: what happened, and when. "Missed" reads better than "0 seconds",
  /// and a call nobody answered has no duration to show.
  static String _describe(Call call, DateTime now) {
    final kind = call.kind == CallKind.audio ? 'Voice' : 'Video';
    final when = timeAgo(call.createdAt, now);

    final what = switch (call.status) {
      CallStatus.missed when !call.isInitiator => 'Missed',
      CallStatus.missed => 'No answer',
      CallStatus.declined when call.isInitiator => 'Declined',
      CallStatus.declined => 'You declined',
      CallStatus.ended => _length(call.durationSeconds),
      CallStatus.ringing || CallStatus.active => 'In progress',
      CallStatus.unknown => 'Call',
    };

    return '$kind · $what · $when';
  }

  static String _length(int? seconds) {
    if (seconds == null || seconds <= 0) return 'No answer';
    if (seconds < 60) return '$seconds sec';

    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    if (minutes < 60) {
      return rest == 0 ? '$minutes min' : '$minutes min $rest sec';
    }

    final hours = minutes ~/ 60;
    return '$hours hr ${minutes % 60} min';
  }
}

class _LoadingMore extends ConsumerWidget {
  const _LoadingMore({required this.failed});

  final bool failed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!failed) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: TextButton(
          onPressed: () =>
              unawaited(ref.read(callHistoryProvider.notifier).loadMore()),
          child: const Text('Could not load more. Try again'),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_outlined, size: 44, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'No calls yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Call a match from your chat with them, with the camera or the '
              'phone at the top.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
