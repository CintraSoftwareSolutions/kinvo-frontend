import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/discover_mode.dart';

final homeTabIndexProvider = StateProvider<int>((_) => 0);

final activeModeIdProvider =
    StateProvider<DiscoverModeId>((_) => DiscoverModeId.cuddle);

final activeModeProvider = Provider<DiscoverMode>((ref) {
  final id = ref.watch(activeModeIdProvider);
  return DiscoverModes.all.firstWhere((m) => m.id == id);
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
