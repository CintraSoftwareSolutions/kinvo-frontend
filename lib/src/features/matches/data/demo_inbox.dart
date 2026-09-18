import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo/demo_mode.dart';
import '../../../core/time/clock.dart';

/// Where one of the demo's matches stands, shared by its match and its
/// conversation so the Matches tab and the chat always agree.
final class DemoMatchState {
  DemoMatchState({
    required this.id,
    required this.mode,
    required this.matchedAt,
    required this.expiresAt,
    required this.lastMessagePreview,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  /// Also the conversation's id, and the sample person's.
  final String id;
  final String mode;
  final DateTime matchedAt;
  DateTime expiresAt;
  String lastMessagePreview;
  DateTime lastMessageAt;
  int unreadCount;
  int extensionCount = 0;
  bool isArchived = false;
  bool isMuted = false;
  bool isUnmatched = false;
}

/// The demo's matches and what's happened in them, kept in memory for as long
/// as the demo runs.
final class DemoInbox {
  DemoInbox({required Clock clock}) : startedAt = clock() {
    for (final (index, (id, mode, preview, unread)) in _samples.indexed) {
      matches.add(
        DemoMatchState(
          id: id,
          mode: mode,
          matchedAt: startedAt.subtract(Duration(days: index + 1)),
          expiresAt: startedAt.add(Duration(days: 13 - index)),
          lastMessagePreview: preview,
          lastMessageAt: startedAt.subtract(Duration(hours: index * 2 + 1)),
          unreadCount: unread,
        ),
      );
    }
  }

  /// Each match's sample person, mode, last message and unread count.
  static const _samples = [
    ('sarah', 'dating', 'Hey! Would love to check out that new café.', 2),
    ('marcus', 'networking', 'The AI conference next week looks great.', 0),
    ('emma', 'study_buddy', 'Should we meet tomorrow to work on it?', 1),
  ];

  /// When the demo started, which its sample times count back from.
  final DateTime startedAt;

  /// Newest match first.
  final List<DemoMatchState> matches = [];

  /// The match with [id], unless there's none or it was unmatched.
  DemoMatchState? find(String id) {
    for (final match in matches) {
      if (match.id == id && !match.isUnmatched) return match;
    }
    return null;
  }
}

/// The demo's inbox, started afresh each time the demo is.
final demoInboxProvider = Provider<DemoInbox>((ref) {
  ref.watch(demoSessionProvider);
  return DemoInbox(clock: ref.watch(clockProvider));
});
