import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/discover_mode.dart';

final homeTabIndexProvider = StateProvider<int>((_) => 0);

final activeModeIdProvider =
    StateProvider<DiscoverModeId>((_) => DiscoverModeId.cuddle);

final activeModeProvider = Provider<DiscoverMode>((ref) {
  final id = ref.watch(activeModeIdProvider);
  return DiscoverModes.byId(id);
});

class HomeBadgeCounts {
  const HomeBadgeCounts({
    required this.notifications,
    required this.matches,
    required this.plans,
    required this.more,
  });

  final int notifications;
  final int matches;
  final int plans;
  final int more;
}

final homeBadgeCountsProvider = Provider<HomeBadgeCounts>((_) {
  return const HomeBadgeCounts(
    notifications: 2,
    matches: 3,
    plans: 2,
    more: 2,
  );
});

class DeckStats {
  const DeckStats({required this.liked, required this.passed, required this.boosts});
  final int liked;
  final int passed;
  final int boosts;
}

class DeckState {
  const DeckState({
    required this.exhaustedModes,
    required this.summaryExpandedModes,
    required this.stats,
  });

  final Set<DiscoverModeId> exhaustedModes;
  final Set<DiscoverModeId> summaryExpandedModes;
  final DeckStats stats;

  bool isExhausted(DiscoverModeId id) => exhaustedModes.contains(id);
  bool isSummaryExpanded(DiscoverModeId id) =>
      summaryExpandedModes.contains(id);

  DeckState copyWith({
    Set<DiscoverModeId>? exhaustedModes,
    Set<DiscoverModeId>? summaryExpandedModes,
    DeckStats? stats,
  }) {
    return DeckState(
      exhaustedModes: exhaustedModes ?? this.exhaustedModes,
      summaryExpandedModes: summaryExpandedModes ?? this.summaryExpandedModes,
      stats: stats ?? this.stats,
    );
  }
}

class DeckController extends Notifier<DeckState> {
  @override
  DeckState build() {
    return const DeckState(
      exhaustedModes: <DiscoverModeId>{},
      summaryExpandedModes: <DiscoverModeId>{},
      stats: DeckStats(liked: 1, passed: 2, boosts: 1),
    );
  }

  void exhaust(DiscoverModeId id) {
    if (state.exhaustedModes.contains(id)) return;
    state = state.copyWith(exhaustedModes: {...state.exhaustedModes, id});
  }

  void reset(DiscoverModeId id) {
    if (!state.exhaustedModes.contains(id)) return;
    state = state.copyWith(
      exhaustedModes: {...state.exhaustedModes}..remove(id),
    );
  }

  void toggleSummary(DiscoverModeId id) {
    final next = {...state.summaryExpandedModes};
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = state.copyWith(summaryExpandedModes: next);
  }

  void closeSummary(DiscoverModeId id) {
    if (!state.summaryExpandedModes.contains(id)) return;
    state = state.copyWith(
      summaryExpandedModes: {...state.summaryExpandedModes}..remove(id),
    );
  }
}

final deckControllerProvider =
    NotifierProvider<DeckController, DeckState>(DeckController.new);

class DiscoveryFilters {
  const DiscoveryFilters({
    required this.distanceMiles,
    required this.verifiedOnly,
    required this.onlineOnly,
  });

  final int distanceMiles;
  final bool verifiedOnly;
  final bool onlineOnly;

  DiscoveryFilters copyWith({
    int? distanceMiles,
    bool? verifiedOnly,
    bool? onlineOnly,
  }) {
    return DiscoveryFilters(
      distanceMiles: distanceMiles ?? this.distanceMiles,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      onlineOnly: onlineOnly ?? this.onlineOnly,
    );
  }
}

class DiscoveryFiltersController extends Notifier<DiscoveryFilters> {
  @override
  DiscoveryFilters build() {
    return const DiscoveryFilters(
      distanceMiles: 10,
      verifiedOnly: true,
      onlineOnly: false,
    );
  }

  void setDistance(int miles) =>
      state = state.copyWith(distanceMiles: miles);
  void toggleVerified() =>
      state = state.copyWith(verifiedOnly: !state.verifiedOnly);
  void toggleOnline() => state = state.copyWith(onlineOnly: !state.onlineOnly);
  void reset() {
    state = const DiscoveryFilters(
      distanceMiles: 10,
      verifiedOnly: true,
      onlineOnly: false,
    );
  }
}

final discoveryFiltersProvider =
    NotifierProvider<DiscoveryFiltersController, DiscoveryFilters>(
  DiscoveryFiltersController.new,
);
