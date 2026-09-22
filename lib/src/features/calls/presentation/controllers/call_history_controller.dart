import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/paged_list.dart';
import '../../../chat/data/live_updates.dart';
import '../../../chat/domain/live_update.dart';
import '../../data/calls_repository.dart';
import '../../domain/call.dart';

/// Every call this account has been in, newest first.
///
/// The list refreshes itself when a call ends rather than being reloaded by
/// the screen: someone who hangs up and goes straight to this list expects the
/// call they just had to be at the top of it.
final class CallHistoryController extends AsyncNotifier<PagedList<Call>> {
  CallsRepository get _repository => ref.read(callsRepositoryProvider);

  @override
  Future<PagedList<Call>> build() async {
    final updates = ref.watch(liveUpdatesProvider).stream.listen((update) {
      // A call that has finished changes what this list should show; one that
      // is still ringing does not, and reloading mid-ring would be a request
      // for nothing.
      if (update case CallChanged(status: final status) when !status.isLive) {
        ref.invalidateSelf();
      }
    });

    ref.onDispose(() => unawaited(updates.cancel()));

    final page = await _repository.fetchHistory();

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

    _update(
      (list) => list.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );

    try {
      final page = await _repository.fetchHistory(cursor: cursor);

      _update((list) {
        // A call can arrive twice when one ends between two pages, which moves
        // everything down by one. Showing it once is the only sane answer.
        final shown = {for (final call in list.items) call.id};

        return list.copyWith(
          items: [
            ...list.items,
            for (final call in page.items)
              if (!shown.contains(call.id)) call,
          ],
          nextCursor: () => page.nextCursor,
          hasMore: page.hasMore,
          isLoadingMore: false,
        );
      });
    } on ApiException {
      _update(
        (list) => list.copyWith(isLoadingMore: false, loadMoreFailed: true),
      );
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  void _update(PagedList<Call> Function(PagedList<Call> list) change) {
    final list = state.value;
    if (list == null) return;
    state = AsyncData(change(list));
  }
}

final callHistoryProvider =
    AsyncNotifierProvider<CallHistoryController, PagedList<Call>>(
      CallHistoryController.new,
    );
