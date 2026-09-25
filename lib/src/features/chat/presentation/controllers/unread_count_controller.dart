import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../../core/auth/session_status.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/realtime/realtime_connection.dart';
import '../../../../core/realtime/realtime_providers.dart';
import '../../data/chat_repository.dart';
import '../../data/live_updates.dart';
import '../../domain/live_update.dart';

/// Unread messages across every conversation, for the Matches tab's badge.
final unreadCountProvider = AsyncNotifierProvider<UnreadCountController, int>(
  UnreadCountController.new,
);

class UnreadCountController extends AsyncNotifier<int> {
  /// How long to wait for a burst of changes to finish before counting again.
  static const settleDelay = Duration(milliseconds: 400);

  Timer? _refreshTimer;

  @override
  Future<int> build() async {
    final signedIn = ref.watch(sessionStatusProvider) is SignedIn;
    final repository = ref.watch(chatRepositoryProvider);
    if (!signedIn) return 0;

    // The server's count is the only one that knows about every conversation,
    // so any change that could move it asks the server again.
    final subscription = ref.watch(liveUpdatesProvider).stream.listen((update) {
      switch (update) {
        case MessageReceived() ||
            ConversationActivity() ||
            MatchCreated() ||
            MatchEnded():
          _scheduleRefresh();
        case _:
          break;
      }
    });
    ref
      ..onDispose(() {
        unawaited(subscription.cancel());
        _refreshTimer?.cancel();
      })
      ..listen(realtimeStatusProvider, (previous, next) {
        if (next == RealtimeStatus.connected &&
            previous != RealtimeStatus.connected) {
          _scheduleRefresh();
        }
      });

    return repository.fetchUnreadCount();
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(settleDelay, () => unawaited(_refresh()));
  }

  Future<void> _refresh() async {
    if (!ref.mounted) return;
    try {
      final count = await ref.read(chatRepositoryProvider).fetchUnreadCount();
      if (ref.mounted) state = AsyncData(count);
    } on ApiException {
      // The badge keeps its last count until the next change.
    }
  }
}
