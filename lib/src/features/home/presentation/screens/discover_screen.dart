import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/home_controller.dart';
import '../../domain/discover_mode.dart';
import '../widgets/deck_controls.dart';
import '../widgets/discover_header.dart';
import '../widgets/discover_info_card.dart';
import '../widgets/discovery_filters_sheet.dart';
import '../widgets/empty_deck_state.dart';
import '../widgets/match_dialog.dart';
import '../widgets/profile_card.dart';
import '../widgets/profile_summary_card.dart';
import '../widgets/select_mode_sheet.dart';

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(activeModeProvider);
    final badges = ref.watch(homeBadgeCountsProvider);
    final deck = ref.watch(deckControllerProvider);
    final deckController = ref.read(deckControllerProvider.notifier);

    final exhausted = deck.isExhausted(mode.id);
    final summaryExpanded = deck.isSummaryExpanded(mode.id);

    return Column(
      children: [
        DiscoverHeader(
          mode: mode,
          notificationCount: badges.notifications,
          onModeTap: () => showSelectModeSheet(context),
          onFiltersTap: () => showDiscoveryFiltersSheet(context),
        ),
        const Divider(height: 1, color: Color(0xFFEDEFF5)),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DiscoverInfoCard(mode: mode),
                const SizedBox(height: 18),
                if (exhausted) ...[
                  EmptyDeckState(
                    mode: mode,
                    stats: deck.stats,
                    onReview: () => deckController.reset(mode.id),
                    onUndo: () => deckController.reset(mode.id),
                    onAdjustFilters: () =>
                        showDiscoveryFiltersSheet(context),
                  ),
                ] else ...[
                  ProfileCard(
                    mode: mode,
                    summaryExpanded: summaryExpanded,
                    onOpenSummary: () => deckController.toggleSummary(mode.id),
                    onPrev: () => _switchMode(ref, -1),
                    onNext: () => _switchMode(ref, 1),
                  ),
                  if (summaryExpanded) ...[
                    const SizedBox(height: 12),
                    ProfileSummaryCard(
                      mode: mode,
                      onCtaTap: () => deckController.closeSummary(mode.id),
                    ),
                  ],
                  const SizedBox(height: 6),
                  DeckControls(
                    mode: mode,
                    onRewind: () => deckController.reset(mode.id),
                    onPass: () => _handlePass(deckController, mode.id),
                    onPrimary: () =>
                        _handlePrimary(context, deckController, mode),
                    onSuperLike: () =>
                        _handleSuperLike(context, deckController, mode),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _switchMode(WidgetRef ref, int delta) {
    final modes = DiscoverModes.all;
    final currentId = ref.read(activeModeIdProvider);
    final index = modes.indexWhere((m) => m.id == currentId);
    final nextIndex = (index + delta) % modes.length;
    final wrapped = nextIndex < 0 ? nextIndex + modes.length : nextIndex;
    ref.read(activeModeIdProvider.notifier).state = modes[wrapped].id;
  }

  void _handlePass(DeckController controller, DiscoverModeId id) {
    controller.exhaust(id);
  }

  Future<void> _handlePrimary(
    BuildContext context,
    DeckController controller,
    DiscoverMode mode,
  ) async {
    if (mode.id == DiscoverModeId.dating) {
      await showMatchDialog(context, mode);
    }
    controller.exhaust(mode.id);
  }

  void _handleSuperLike(
    BuildContext context,
    DeckController controller,
    DiscoverMode mode,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Super Liked ${mode.profile.name}')),
    );
    controller.exhaust(mode.id);
  }
}
