import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/widgets/flow_widgets.dart';
import '../../../../core/widgets/paywall_sheet.dart';
import '../../../matches/presentation/controllers/matches_controllers.dart';
import '../../../notifications/presentation/controllers/notifications_controllers.dart';
import '../../../modes/presentation/mode_presentation.dart';
import '../../../settings/presentation/controllers/settings_controllers.dart';
import '../../domain/deck_card.dart';
import '../../domain/deck_stats.dart';
import '../../domain/discovery_formatting.dart';
import '../../domain/discovery_mode.dart';
import '../../domain/swipe.dart';
import '../controllers/deck_controller.dart';
import '../controllers/discovery_actions.dart';
import '../controllers/discovery_modes_controller.dart';
import '../widgets/deck_card_view.dart';
import '../widgets/deck_controls.dart';
import '../widgets/deck_summary_card.dart';
import '../widgets/discover_header.dart';
import '../widgets/empty_deck.dart';
import '../widgets/filters_sheet.dart';
import '../widgets/match_dialog.dart';
import '../widgets/mode_picker_sheet.dart';
import '../widgets/profile_sheet.dart';

/// The Discover tab: today's deck for one of the user's modes.
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeDiscoveryModeProvider);
    final mode = active.value;
    final modes = ref.watch(discoveryModesProvider).value ?? const [];

    return Column(
      children: [
        DiscoverHeader(
          modeLabel: mode?.label ?? 'Discover',
          modeColor: mode == null
              ? AppColors.purple
              : modeColors(mode.value).primary,
          notificationCount:
              ref.watch(notificationUnreadCountProvider).value ?? 0,
          onModeTap: mode == null || modes.length < 2
              ? null
              : () => _pickMode(context, ref, modes, mode),
          onFiltersTap: mode == null
              ? null
              : () => showFiltersSheet(context, mode),
          onNotificationsTap: () => context.push(AppRoutes.notifications),
        ),
        const Divider(height: 1, color: Color(0xFFEDEFF5)),
        Expanded(
          child: active.hasValue
              ? switch (mode) {
                  final mode? => _ModeDeck(
                    key: ValueKey(mode.value),
                    mode: mode,
                    modes: modes,
                  ),
                  null => _Message(
                    title: 'No modes switched on',
                    message:
                        'Discover shows people for the modes you use. '
                        'Switch one on to start.',
                    onRetry: () => ref.invalidate(discoveryModesProvider),
                  ),
                }
              : active.hasError
              ? _Message(
                  title: "Discover didn't load",
                  message: _messageFor(active.error),
                  onRetry: () => ref.invalidate(discoveryModesProvider),
                )
              : const Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }

  static Future<void> _pickMode(
    BuildContext context,
    WidgetRef ref,
    List<DiscoveryMode> modes,
    DiscoveryMode active,
  ) async {
    final picked = await showModePickerSheet(
      context,
      modes: modes,
      activeMode: active.value,
    );
    if (picked != null) {
      ref.read(selectedDiscoveryModeProvider.notifier).select(picked.value);
    }
  }
}

/// One mode's deck, with the summary above it.
class _ModeDeck extends ConsumerWidget {
  const _ModeDeck({required this.mode, required this.modes, super.key});

  final DiscoveryMode mode;
  final List<DiscoveryMode> modes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deck = ref.watch(deckControllerProvider(mode.value));
    final stats = ref.watch(deckStatsProvider(mode.value));
    final isStartingBoost = ref.watch(boostControllerProvider(mode.value));
    final interestLabels = ref.watch(interestLabelsProvider);
    final now = ref.watch(clockProvider)();
    final colors = modeColors(mode.value);

    String interestLabel(String slug) => interestLabels[slug] ?? humanise(slug);

    Future<void> refresh() async {
      try {
        await (
          ref.read(deckControllerProvider(mode.value).notifier).reload(),
          ref.refresh(deckStatsProvider(mode.value).future),
        ).wait;
      } on Object {
        // Whatever failed shows on the screen with a way to try again.
      }
    }

    final Widget body;
    // A failed reload keeps the cards from before it, which are out of date
    // — after new filters, say — so the failure shows instead of them.
    if (deck.hasError && !deck.isLoading) {
      body = _Message(
        title: "The deck didn't load",
        message: _messageFor(deck.error),
        onRetry: () => ref.invalidate(deckControllerProvider(mode.value)),
      );
    } else if (deck.value case final state?) {
      body = _DeckBody(
        mode: mode,
        modes: modes,
        state: state,
        // Cards from before a reload stay on show until the new ones arrive,
        // but can't be answered in the meantime.
        isReloading: deck.isLoading,
        stats: stats.value,
        interestLabel: interestLabel,
        now: now,
      );
    } else {
      body = const _CardPlaceholder();
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DeckSummaryCard(
              modeLabel: mode.label,
              modeColor: colors.primary,
              modeSoftColor: colors.soft,
              allowance: deck.value?.allowance ?? stats.value?.allowance,
              boost: stats.value?.boost,
              isStartingBoost: isStartingBoost,
              onBoost: () => _boost(context, ref, mode),
              now: now,
            ),
            const SizedBox(height: 18),
            body,
          ],
        ),
      ),
    );
  }

  static Future<void> _boost(
    BuildContext context,
    WidgetRef ref,
    DiscoveryMode mode,
  ) async {
    final outcome = await ref
        .read(boostControllerProvider(mode.value).notifier)
        .start();
    if (!context.mounted) return;
    switch (outcome) {
      case BoostStarted(:final boost):
        final minutes = boost.endsAt.difference(boost.startedAt).inMinutes;
        _tell(
          context,
          "You're boosted in ${mode.label} for the next $minutes minutes.",
        );
      case BoostNeedsUpgrade(:final paywall):
        await showPaywallSheet(context, paywall);
      case BoostFailed(:final message):
        _tell(context, message);
      case null:
        break;
    }
  }
}

/// The deck once it's loaded: the card and its controls, or the empty state.
class _DeckBody extends ConsumerWidget {
  const _DeckBody({
    required this.mode,
    required this.modes,
    required this.state,
    required this.isReloading,
    required this.stats,
    required this.interestLabel,
    required this.now,
  });

  final DiscoveryMode mode;
  final List<DiscoveryMode> modes;
  final DeckState state;
  final bool isReloading;
  final DeckStats? stats;
  final String Function(String slug) interestLabel;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(deckControllerProvider(mode.value).notifier);
    final colors = modeColors(mode.value);
    final card = state.current;

    if (card == null) {
      if (state.hasMore) {
        if (state.loadMoreFailed) {
          return _Message(
            title: "More people didn't load",
            message: 'Check your connection and try again.',
            onRetry: notifier.loadMore,
          );
        }
        if (!state.isLoadingMore) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            notifier.loadMore();
          });
        }
        return const _CardPlaceholder();
      }
      return EmptyDeck(
        modeLabel: mode.label,
        stats: stats,
        onRewind: () => _rewind(context, ref, mode),
        onAdjustFilters: () => showFiltersSheet(context, mode),
        onRefresh: () {
          ref
            ..invalidate(deckControllerProvider(mode.value))
            ..invalidate(deckStatsProvider(mode.value));
        },
      );
    }

    final index = modes.indexWhere((each) => each.value == mode.value);
    void switchMode(int step) {
      final next = modes[(index + step) % modes.length];
      ref.read(selectedDiscoveryModeProvider.notifier).select(next.value);
    }

    final canSwitch = modes.length > 1 && index >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PrecacheNext(card: state.cards.elementAtOrNull(1)),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: DeckCardView(
            key: ValueKey(card.entryId),
            card: card,
            modeLabel: mode.label,
            modeIcon: modeIconAsset(mode.value),
            modeColor: colors.primary,
            interestLabel: interestLabel,
            now: now,
            distanceUnit: ref.watch(distanceUnitProvider),
            onOpenProfile: () => showProfileSheet<void>(
              context,
              user: card.user,
              accent: colors.primary,
            ),
            onPreviousMode: canSwitch ? () => switchMode(-1) : null,
            onNextMode: canSwitch ? () => switchMode(1) : null,
          ),
        ),
        const SizedBox(height: 14),
        DeckControls(
          likeLabel: mode.likeLabel,
          superLikeLabel: mode.superLikeLabel,
          modeIcon: modeIconAsset(mode.value),
          modeColor: colors.primary,
          enabled: !state.isSwiping && !isReloading,
          onRewind: () => _rewind(context, ref, mode),
          onPass: () => _swipe(context, ref, mode, SwipeAction.pass),
          onLike: () => _swipe(context, ref, mode, SwipeAction.like),
          onSuperLike: () => _swipe(context, ref, mode, SwipeAction.superLike),
        ),
      ],
    );
  }

  static Future<void> _swipe(
    BuildContext context,
    WidgetRef ref,
    DiscoveryMode mode,
    SwipeAction action,
  ) async {
    final outcome = await ref
        .read(deckControllerProvider(mode.value).notifier)
        .swipe(action);
    if (!context.mounted) return;
    switch (outcome) {
      case Swiped(:final card, result: SwipeResult(match: _?)):
        // The Matches tab shows the new match next time it's opened.
        ref.invalidate(matchesListProvider(false));
        final colors = modeColors(mode.value);
        final choice = await showMatchDialog(
          context,
          user: card.user,
          modeLabel: mode.label,
          modeColor: colors.primary,
          modeSoftColor: colors.soft,
        );
        if (choice == MatchDialogChoice.seeMatches && context.mounted) {
          context.go(AppRoutes.matches);
        }
      case SwipeNeedsUpgrade(:final paywall):
        await showPaywallSheet(context, paywall);
      case SwipeFailed(:final message):
        _tell(context, message);
      case Swiped() || CardGone() || null:
        break;
    }
  }

  static Future<void> _rewind(
    BuildContext context,
    WidgetRef ref,
    DiscoveryMode mode,
  ) async {
    final outcome = await ref
        .read(deckControllerProvider(mode.value).notifier)
        .rewind();
    if (!context.mounted) return;
    switch (outcome) {
      case Rewound(:final result) when result.matchRemoved:
        ref.invalidate(matchesListProvider(false));
        _tell(context, 'Your last swipe is back, and its match is undone.');
      case Rewound():
        _tell(context, 'Your last swipe is back.');
      case RewindNeedsUpgrade(:final paywall):
        await showPaywallSheet(context, paywall);
      case RewindFailed(:final message):
        _tell(context, message);
      case null:
        break;
    }
  }
}

/// Starts loading the next card's photo, so it shows at once when its turn
/// comes.
class _PrecacheNext extends StatefulWidget {
  const _PrecacheNext({required this.card});

  final DeckCard? card;

  @override
  State<_PrecacheNext> createState() => _PrecacheNextState();
}

class _PrecacheNextState extends State<_PrecacheNext> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precache();
  }

  @override
  void didUpdateWidget(_PrecacheNext oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card?.entryId != widget.card?.entryId) _precache();
  }

  void _precache() {
    final url = widget.card?.user.photoUrl;
    if (url == null || !(url.isScheme('https') || url.isScheme('http'))) {
      return;
    }
    // A photo that fails here fails again when shown, and shows the initial.
    precacheImage(NetworkImage(url.toString()), context, onError: (_, _) {});
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _CardPlaceholder extends StatelessWidget {
  const _CardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: const AspectRatio(
        aspectRatio: 0.78,
        child: ColoredBox(
          color: AppColors.surfaceSoft,
          child: Center(child: CircularProgressIndicator()),
        ),
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
    return Container(
      margin: const EdgeInsets.all(18),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
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
    );
  }
}

String _messageFor(Object? error) {
  return error is ApiException
      ? error.message
      : 'Something went wrong. Please try again.';
}

void _tell(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
