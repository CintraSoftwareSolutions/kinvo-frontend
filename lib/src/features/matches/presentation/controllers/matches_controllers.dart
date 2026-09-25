import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/entitlements/paywall.dart';
import '../../../../core/network/api_error_code.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/paged_list.dart';
import '../../../../core/realtime/realtime_connection.dart';
import '../../../../core/realtime/realtime_providers.dart';
import '../../../chat/data/live_updates.dart';
import '../../../chat/domain/live_update.dart';
import '../../../discovery/data/discovery_repository.dart';
import '../../../discovery/domain/swipe.dart';
import '../../../discovery/presentation/controllers/deck_controller.dart';
import '../../data/matches_repository.dart';
import '../../domain/match_summary.dart';

/// The tabs of the Matches screen.
enum MatchesTab { matches, requests, archived }

/// The tab open on the Matches screen.
final matchesTabProvider = NotifierProvider<MatchesTabController, MatchesTab>(
  MatchesTabController.new,
);

class MatchesTabController extends Notifier<MatchesTab> {
  @override
  MatchesTab build() {
    ref.watch(matchesRepositoryProvider);
    return MatchesTab.matches;
  }

  void select(MatchesTab tab) => state = tab;
}

/// Matches expiring within this long offer to be extended.
const extendOfferWithin = Duration(days: 3);

/// How extending a match turned out.
@immutable
sealed class ExtendOutcome {
  const ExtendOutcome();
}

final class Extended extends ExtendOutcome {
  const Extended(this.match);

  final MatchSummary match;
}

final class ExtendNeedsUpgrade extends ExtendOutcome {
  const ExtendNeedsUpgrade(this.paywall);

  final Paywall paywall;
}

final class ExtendFailed extends ExtendOutcome {
  const ExtendFailed(this.message);

  final String message;
}

/// Ends matches from wherever the user decides to: a list, or Discover when
/// a rewind turns out to be a match.
final matchEndingProvider = Provider<MatchEnding>((ref) {
  return MatchEnding(
    repository: ref.watch(matchesRepositoryProvider),
    updates: ref.watch(liveUpdatesProvider),
  );
});

final class MatchEnding {
  const MatchEnding({
    required MatchesRepository repository,
    required LiveUpdates updates,
  }) : _repository = repository,
       _updates = updates;

  final MatchesRepository _repository;
  final LiveUpdates _updates;

  /// Ends the match for both people, and tells every list showing it.
  /// Returns why it failed, or `null` once it's done.
  Future<String?> unmatch(String matchId) async {
    try {
      await _repository.unmatch(matchId);
    } on ApiException catch (error) {
      // Already gone is what the user wanted.
      if (error is! ApiErrorException || error.statusCode != 404) {
        return error.message;
      }
    }
    _updates.publish(MatchEnded(matchId));
    return null;
  }
}

/// Matches, newest first: current ones, or archived ones when the argument is
/// true.
final matchesListProvider = AsyncNotifierProvider.autoDispose
    .family<MatchesListController, PagedList<MatchSummary>, bool>(
      MatchesListController.new,
    );

class MatchesListController extends AsyncNotifier<PagedList<MatchSummary>> {
  MatchesListController(this.archived);

  final bool archived;

  MatchesRepository get _repository => ref.read(matchesRepositoryProvider);

  @override
  Future<PagedList<MatchSummary>> build() async {
    final subscription = ref.watch(liveUpdatesProvider).stream.listen(_apply);
    ref
      ..onDispose(() => unawaited(subscription.cancel()))
      ..listen(realtimeStatusProvider, (previous, next) {
        // Changes made while the live connection was away never arrived.
        if (next == RealtimeStatus.connected &&
            previous != RealtimeStatus.connected &&
            state.hasValue) {
          ref.invalidateSelf();
        }
      });

    final page = await ref
        .watch(matchesRepositoryProvider)
        .fetchMatches(archived: archived);
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

    state = AsyncData(
      list.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );
    try {
      final page = await _repository.fetchMatches(
        archived: archived,
        cursor: cursor,
      );
      if (!ref.mounted) return;
      _update((list) {
        final shown = {for (final match in list.items) match.id};
        return list.copyWith(
          items: [
            ...list.items,
            for (final match in page.items)
              if (!shown.contains(match.id)) match,
          ],
          nextCursor: () => page.nextCursor,
          hasMore: page.hasMore,
          isLoadingMore: false,
        );
      });
    } on ApiException {
      if (!ref.mounted) return;
      _update((list) {
        return list.copyWith(isLoadingMore: false, loadMoreFailed: true);
      });
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Ends the match for both people. Returns why it failed, or `null` once
  /// it's done.
  Future<String?> unmatch(String matchId) async {
    final error = await ref.read(matchEndingProvider).unmatch(matchId);
    // At once, rather than when the announcement comes round.
    if (error == null && ref.mounted) {
      _removeWhere((match) => match.id == matchId);
    }
    return error;
  }

  Future<ExtendOutcome> extend(String matchId) async {
    final updates = ref.read(liveUpdatesProvider);
    try {
      final extended = await _repository.extend(matchId);
      _replaceWhere((match) => match.id == matchId, (_) => extended);
      updates.publish(MatchChanged(extended));
      return Extended(extended);
    } on ApiException catch (error) {
      if (Paywall.fromError(error) case final paywall?) {
        return ExtendNeedsUpgrade(paywall);
      }
      return ExtendFailed(error.message);
    }
  }

  /// Keeps the list in step with changes made elsewhere: new messages,
  /// people coming online, and matches made, changed or ended.
  void _apply(LiveUpdate update) {
    switch (update) {
      case ConversationActivity(:final conversationId, :final isArchived)
          when isArchived != null && isArchived != archived:
        // Moved to the other list.
        _removeWhere((match) => match.conversationId == conversationId);

      case ConversationActivity(:final conversationId, :final isArchived)
          when isArchived == archived && _isMissing(conversationId):
        // Moved here from the other list, which is where its details are.
        ref.invalidateSelf();

      case ConversationActivity(
        :final conversationId,
        :final lastMessageAt,
        :final lastMessagePreview,
        :final unreadCount,
      ):
        _replaceWhere(
          (match) => match.conversationId == conversationId,
          (match) => match.copyWith(
            lastMessageAt: lastMessageAt,
            lastMessagePreview: lastMessagePreview,
            unreadCount: unreadCount,
          ),
        );

      case PresenceChanged(:final userId, :final isOnline, :final lastActiveAt):
        _replaceWhere(
          (match) => match.user.id == userId,
          (match) => match.copyWith(
            user: match.user.withPresence(
              isOnline: isOnline,
              lastActiveAt: lastActiveAt,
            ),
          ),
        );

      case MatchCreated(:final match) when !archived:
        _update((list) {
          if (list.items.any((each) => each.id == match.id)) return list;
          return list.copyWith(items: [match, ...list.items]);
        });

      case MatchChanged(:final match):
        _replaceWhere((each) => each.id == match.id, (_) => match);

      case MatchEnded(:final matchId):
        _removeWhere((match) => match.id == matchId);

      case _:
        break;
    }
  }

  /// Whether the whole list has loaded without [conversationId] in it. With
  /// more pages to come, it may just be further down.
  bool _isMissing(String conversationId) {
    final list = state.value;
    return list != null &&
        !list.hasMore &&
        !list.items.any((match) => match.conversationId == conversationId);
  }

  void _replaceWhere(
    bool Function(MatchSummary match) test,
    MatchSummary Function(MatchSummary match) replace,
  ) {
    _update((list) {
      if (!list.items.any(test)) return list;
      return list.copyWith(
        items: [
          for (final match in list.items) test(match) ? replace(match) : match,
        ],
      );
    });
  }

  void _removeWhere(bool Function(MatchSummary match) test) {
    _update((list) {
      if (!list.items.any(test)) return list;
      return list.copyWith(
        items: [
          for (final match in list.items)
            if (!test(match)) match,
        ],
      );
    });
  }

  void _update(
    PagedList<MatchSummary> Function(PagedList<MatchSummary> list) change,
  ) {
    if (!ref.mounted) return;
    if (state.value case final list?) {
      final changed = change(list);
      if (!identical(changed, list)) state = AsyncData(changed);
    }
  }
}

/// How answering someone in the likes inbox turned out.
@immutable
sealed class AnswerOutcome {
  const AnswerOutcome();
}

final class Answered extends AnswerOutcome {
  const Answered(this.result);

  final SwipeResult result;
}

/// Already answered, on another device, or no longer around.
final class AnswerGone extends AnswerOutcome {
  const AnswerGone();
}

final class AnswerNeedsUpgrade extends AnswerOutcome {
  const AnswerNeedsUpgrade(this.paywall);

  final Paywall paywall;
}

final class AnswerFailed extends AnswerOutcome {
  const AnswerFailed(this.message);

  final String message;
}

/// The likes inbox for one mode.
@immutable
sealed class LikesInbox {
  const LikesInbox();
}

/// Who liked the user, which their plan lets them see.
final class LikesVisible extends LikesInbox {
  const LikesVisible(this.likes);

  final PagedList<LikeReceived> likes;
}

/// Who liked the user is part of a paid plan they don't have. [waiting] says
/// how many there are, without saying who.
final class LikesLocked extends LikesInbox {
  const LikesLocked({required this.paywall, required this.waiting});

  final PremiumFeature paywall;

  /// People waiting, or `null` if that couldn't be read.
  final int? waiting;
}

/// The likes inbox for the mode given, by its API name.
final likesInboxProvider = AsyncNotifierProvider.autoDispose
    .family<LikesInboxController, LikesInbox, String>(LikesInboxController.new);

class LikesInboxController extends AsyncNotifier<LikesInbox> {
  LikesInboxController(this.mode);

  final String mode;

  @override
  Future<LikesInbox> build() async {
    final subscription = ref.watch(liveUpdatesProvider).stream.listen((update) {
      if (update is SubscriptionChanged) ref.invalidateSelf();
    });
    ref.onDispose(() => unawaited(subscription.cancel()));

    try {
      final page = await ref.watch(matchesRepositoryProvider).fetchLikes(mode);
      return LikesVisible(
        PagedList(
          items: page.items,
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
        ),
      );
    } on ApiException catch (error) {
      if (Paywall.fromError(error) case final PremiumFeature paywall) {
        return LikesLocked(paywall: paywall, waiting: await _waiting());
      }
      rethrow;
    }
  }

  /// How many people are waiting, from the deck stats, which say how many
  /// without saying who.
  Future<int?> _waiting() async {
    try {
      final stats = await ref
          .read(discoveryRepositoryProvider)
          .fetchStats(mode);
      return stats.likesReceived;
    } on ApiException {
      return null;
    }
  }

  Future<void> loadMore() async {
    final inbox = state.value;
    if (inbox is! LikesVisible) return;
    final likes = inbox.likes;
    final cursor = likes.nextCursor;
    if (!likes.hasMore || likes.isLoadingMore || cursor == null) return;

    state = AsyncData(
      LikesVisible(likes.copyWith(isLoadingMore: true, loadMoreFailed: false)),
    );
    try {
      final page = await ref
          .read(matchesRepositoryProvider)
          .fetchLikes(mode, cursor: cursor);
      if (!ref.mounted) return;
      final shown = {for (final like in likes.items) like.swipeId};
      state = AsyncData(
        LikesVisible(
          likes.copyWith(
            items: [
              ...likes.items,
              for (final like in page.items)
                if (!shown.contains(like.swipeId)) like,
            ],
            nextCursor: () => page.nextCursor,
            hasMore: page.hasMore,
            isLoadingMore: false,
          ),
        ),
      );
    } on ApiException {
      if (!ref.mounted) return;
      state = AsyncData(
        LikesVisible(
          likes.copyWith(isLoadingMore: false, loadMoreFailed: true),
        ),
      );
    }
  }

  /// Answers [like] with [action], as a swipe in this mode would.
  ///
  /// Whatever the answer, the person leaves the inbox. So does anyone already
  /// answered elsewhere or no longer around, which the server reports the
  /// same way.
  Future<AnswerOutcome> answer(LikeReceived like, SwipeAction action) async {
    try {
      final result = await ref
          .read(discoveryRepositoryProvider)
          .swipe(mode, userId: like.user.id, action: action);
      _answered(like.user.id);
      return Answered(result);
    } on ApiException catch (error) {
      if (Paywall.fromError(error) case final paywall?) {
        return AnswerNeedsUpgrade(paywall);
      }
      if (error case ApiErrorException(
        code: ApiErrorCode.conflict || ApiErrorCode.notFound,
      )) {
        _answered(like.user.id);
        return const AnswerGone();
      }
      return AnswerFailed(error.message);
    }
  }

  /// Takes someone off the list once they've been answered, and marks what
  /// else that changes as out of date: the deck may have held them, and the
  /// answer may have made a match.
  void _answered(String userId) {
    ref
      ..invalidate(deckControllerProvider(mode))
      ..invalidate(deckStatsProvider(mode))
      ..invalidate(matchesListProvider(false));
    if (!ref.mounted) return;
    _removeFromInbox(userId);
  }

  void _removeFromInbox(String userId) {
    final inbox = state.value;
    if (inbox is! LikesVisible) return;
    state = AsyncData(
      LikesVisible(
        inbox.likes.copyWith(
          items: [
            for (final like in inbox.likes.items)
              if (like.user.id != userId) like,
          ],
        ),
      ),
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
