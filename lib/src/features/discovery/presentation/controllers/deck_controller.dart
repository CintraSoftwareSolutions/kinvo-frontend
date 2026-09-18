import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/entitlements/paywall.dart';
import '../../../../core/network/api_error_code.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/discovery_repository.dart';
import '../../domain/deck_card.dart';
import '../../domain/deck_stats.dart';
import '../../domain/swipe.dart';
import 'discovery_modes_controller.dart';

/// Today's deck for one mode, as the user works through it.
@immutable
final class DeckState {
  const DeckState({
    required this.cards,
    required this.nextCursor,
    required this.hasMore,
    this.allowance,
    this.isSwiping = false,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  /// Cards not swiped yet, the one on show first.
  final List<DeckCard> cards;

  /// Where the next page starts, when there is one.
  final String? nextCursor;
  final bool hasMore;

  /// What's left of today's likes, as the last swipe reported it. `null`
  /// until the first swipe; the deck stats say it before then.
  final SwipeAllowance? allowance;

  /// A swipe is on its way to the server. Swipes go one at a time, so the
  /// server records them in the order they were made.
  final bool isSwiping;

  final bool isLoadingMore;

  /// The last attempt to fetch more cards failed.
  final bool loadMoreFailed;

  DeckCard? get current => cards.firstOrNull;

  /// Nothing left today: no cards on hand and none to fetch.
  bool get isExhausted => cards.isEmpty && !hasMore;

  DeckState copyWith({
    List<DeckCard>? cards,
    ValueGetter<String?>? nextCursor,
    bool? hasMore,
    SwipeAllowance? allowance,
    bool? isSwiping,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) {
    return DeckState(
      cards: cards ?? this.cards,
      nextCursor: nextCursor == null ? this.nextCursor : nextCursor(),
      hasMore: hasMore ?? this.hasMore,
      allowance: allowance ?? this.allowance,
      isSwiping: isSwiping ?? this.isSwiping,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }
}

/// How a swipe turned out.
@immutable
sealed class SwipeOutcome {
  const SwipeOutcome();
}

/// The server recorded the swipe.
final class Swiped extends SwipeOutcome {
  const Swiped({required this.card, required this.result});

  final DeckCard card;
  final SwipeResult result;
}

/// The card was no longer there to swipe: already answered on another device,
/// or the person left or can't be shown any more. It's gone from the deck
/// and there is nothing to tell the user.
final class CardGone extends SwipeOutcome {
  const CardGone();
}

/// The swipe needs an upgrade, such as when today's likes are used up. The
/// card stays on show.
final class SwipeNeedsUpgrade extends SwipeOutcome {
  const SwipeNeedsUpgrade(this.paywall);

  final Paywall paywall;
}

/// The swipe didn't reach the server or wasn't accepted. The card stays on
/// show, so the user can try again.
final class SwipeFailed extends SwipeOutcome {
  const SwipeFailed(this.message);

  final String message;
}

/// How rewinding turned out.
@immutable
sealed class RewindOutcome {
  const RewindOutcome();
}

final class Rewound extends RewindOutcome {
  const Rewound(this.result);

  final RewindResult result;
}

final class RewindNeedsUpgrade extends RewindOutcome {
  const RewindNeedsUpgrade(this.paywall);

  final Paywall paywall;
}

/// Nothing to rewind, or it didn't work. [message] says which.
final class RewindFailed extends RewindOutcome {
  const RewindFailed(this.message);

  final String message;
}

/// Today's deck for the mode given, by its API name.
final deckControllerProvider = AsyncNotifierProvider.autoDispose
    .family<DeckController, DeckState, String>(DeckController.new);

class DeckController extends AsyncNotifier<DeckState> {
  DeckController(this.mode);

  /// Fetch the next page once this few cards are left, so the next card is
  /// ready before it's needed.
  static const refillBelow = 5;

  final String mode;

  DiscoveryRepository get _repository => ref.read(discoveryRepositoryProvider);

  @override
  Future<DeckState> build() async {
    final page = await ref.watch(discoveryRepositoryProvider).fetchDeck(mode);
    return DeckState(
      cards: page.items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
  }

  /// Answers the card on show with [action].
  ///
  /// The next card shows at once rather than after the server replies. If the
  /// swipe fails, the card comes back.
  ///
  /// Returns `null` when there was nothing to swipe, or a swipe was already
  /// on its way.
  Future<SwipeOutcome?> swipe(SwipeAction action) async {
    final deck = state.value;
    final card = deck?.current;
    if (deck == null || card == null || deck.isSwiping) return null;

    state = AsyncData(
      deck.copyWith(cards: deck.cards.skip(1).toList(), isSwiping: true),
    );

    try {
      final result = await _repository.swipe(
        mode,
        userId: card.user.id,
        action: action,
      );
      if (!ref.mounted) return Swiped(card: card, result: result);

      _update((deck) {
        return deck.copyWith(isSwiping: false, allowance: result.allowance);
      });
      if (result.match != null) {
        // The empty deck's stats count matches.
        ref.invalidate(deckStatsProvider(mode));
      }
      await _refillIfLow();
      return Swiped(card: card, result: result);
    } on ApiException catch (error) {
      final outcome = _swipeFailed(error);
      if (ref.mounted) {
        _update((deck) {
          return deck.copyWith(
            isSwiping: false,
            // Put the card back unless it's gone for good.
            cards: outcome is CardGone ? null : [card, ...deck.cards],
          );
        });
        if (outcome is CardGone) await _refillIfLow();
      }
      return outcome;
    }
  }

  SwipeOutcome _swipeFailed(ApiException error) {
    if (Paywall.fromError(error) case final paywall?) {
      return SwipeNeedsUpgrade(paywall);
    }
    return switch (error) {
      ApiErrorException(code: ApiErrorCode.conflict || ApiErrorCode.notFound) =>
        const CardGone(),
      ApiErrorException(code: ApiErrorCode.badRequest, :final details)
          when details?['is_enabled'] == false =>
        _modeSwitchedOff(error.message),
      _ => SwipeFailed(error.message),
    };
  }

  /// The mode was switched off on another device. Discover moves to one that
  /// is still on.
  SwipeOutcome _modeSwitchedOff(String message) {
    ref.invalidate(discoveryModesProvider);
    return SwipeFailed(message);
  }

  /// Fetches the next page, if the deck is running low and there is one.
  Future<void> loadMore() async {
    final deck = state.value;
    final cursor = deck?.nextCursor;
    if (deck == null || !deck.hasMore || deck.isLoadingMore || cursor == null) {
      return;
    }

    state = AsyncData(
      deck.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );
    try {
      final page = await _repository.fetchDeck(mode, cursor: cursor);
      if (!ref.mounted) return;
      _update((deck) {
        final shown = {for (final card in deck.cards) card.entryId};
        return deck.copyWith(
          cards: [
            ...deck.cards,
            for (final card in page.items)
              if (!shown.contains(card.entryId)) card,
          ],
          nextCursor: () => page.nextCursor,
          hasMore: page.hasMore,
          isLoadingMore: false,
        );
      });
    } on ApiException {
      if (!ref.mounted) return;
      _update((deck) {
        return deck.copyWith(isLoadingMore: false, loadMoreFailed: true);
      });
    }
  }

  /// Undoes the last swipe in this mode and puts that card back on top.
  Future<RewindOutcome?> rewind() async {
    final deck = state.value;
    if (deck == null || deck.isSwiping) return null;

    try {
      final result = await _repository.rewind(mode);
      if (!ref.mounted) return Rewound(result);

      // The card goes back to its old place in the deck, ahead of everything
      // on hand, so the deck is read again from the start.
      final page = await _repository.fetchDeck(mode);
      if (!ref.mounted) return Rewound(result);
      state = AsyncData(
        DeckState(
          cards: page.items,
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
          allowance: state.value?.allowance,
        ),
      );
      ref.invalidate(deckStatsProvider(mode));
      return Rewound(result);
    } on ApiException catch (error) {
      if (Paywall.fromError(error) case final paywall?) {
        return RewindNeedsUpgrade(paywall);
      }
      return RewindFailed(error.message);
    }
  }

  /// Reads the deck again from the start.
  Future<void> reload() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> _refillIfLow() async {
    final deck = state.value;
    if (deck != null && deck.cards.length < refillBelow) await loadMore();
  }

  void _update(DeckState Function(DeckState deck) change) {
    if (state.value case final deck?) state = AsyncData(change(deck));
  }
}

/// Where the user stands with the mode given today: swipes, matches, cards
/// left, boost and likes left.
final deckStatsProvider = FutureProvider.autoDispose.family<DeckStats, String>(
  (ref, mode) => ref.watch(discoveryRepositoryProvider).fetchStats(mode),
);
