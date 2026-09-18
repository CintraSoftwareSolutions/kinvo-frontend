import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/presentation/controllers/unread_count_controller.dart';
import '../../../notifications/presentation/controllers/notifications_controllers.dart';
import '../../../plans/presentation/controllers/plans_controllers.dart';

/// The counts on the bottom navigation.
@immutable
final class HomeBadgeCounts {
  const HomeBadgeCounts({
    required this.matches,
    required this.plans,
    required this.more,
  });

  static const none = HomeBadgeCounts(matches: 0, plans: 0, more: 0);

  final int matches;
  final int plans;
  final int more;
}

/// The counts on the bottom navigation.
///
/// Matches counts unread messages, Plans the plans waiting on the user's
/// answer, and More unread notifications, whose list is there.
final homeBadgeCountsProvider = Provider<HomeBadgeCounts>((ref) {
  final messages = ref.watch(unreadCountProvider).value ?? 0;
  final plans = ref.watch(plansAwaitingAnswerProvider).value ?? 0;
  final notifications = ref.watch(notificationUnreadCountProvider).value ?? 0;
  return HomeBadgeCounts(matches: messages, plans: plans, more: notifications);
});
