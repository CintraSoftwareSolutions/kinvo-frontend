import '../../../core/network/api_error_code.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/cursor_page.dart';
import '../../../core/time/clock.dart';
import '../../discovery/data/demo_people.dart';
import '../domain/match_summary.dart';
import 'demo_inbox.dart';
import 'matches_repository.dart';

/// The Matches tab for the demo: sample matches and likes, kept in [DemoInbox]
/// so the demo's conversations agree with it.
///
/// Match ids are the sample people's ids, which also name their
/// conversations.
final class DemoMatchesRepository implements MatchesRepository {
  DemoMatchesRepository({required DemoInbox inbox, required Clock clock})
    : _inbox = inbox,
      _clock = clock;

  static const _likes = [('olivia', 'dating', true), ('noah', 'dating', false)];

  final DemoInbox _inbox;
  final Clock _clock;

  @override
  Future<CursorPage<MatchSummary>> fetchMatches({
    required bool archived,
    String? cursor,
  }) async {
    final items = [
      for (final match in _inbox.matches)
        if (!match.isUnmatched && match.isArchived == archived)
          ?_summaryOf(match),
    ];
    return CursorPage(
      items: items,
      nextCursor: null,
      hasMore: false,
      limit: items.length,
    );
  }

  @override
  Future<MatchSummary> fetchMatch(String matchId) async {
    return _summaryOf(_find(matchId)) ?? (throw _notFound);
  }

  @override
  Future<CursorPage<LikeReceived>> fetchLikes(
    String mode, {
    String? cursor,
  }) async {
    final now = _clock();
    final items = [
      for (final (index, (id, likedIn, isSuperLike)) in _likes.indexed)
        if (likedIn == mode)
          if (demoPersonById(id) case final person?)
            LikeReceived(
              swipeId: 'demo-like-$id',
              isSuperLike: isSuperLike,
              likedAt: now.subtract(Duration(hours: index + 3)),
              user: person.summaryAt(now),
            ),
    ];
    return CursorPage(
      items: items,
      nextCursor: null,
      hasMore: false,
      limit: items.length,
    );
  }

  @override
  Future<void> unmatch(String matchId) async {
    _find(matchId).isUnmatched = true;
  }

  @override
  Future<MatchSummary> extend(String matchId) async {
    final match = _find(matchId);
    final now = _clock();
    final from = match.expiresAt.isAfter(now) ? match.expiresAt : now;
    match
      ..expiresAt = from.add(const Duration(days: 7))
      ..extensionCount += 1;
    return fetchMatch(matchId);
  }

  MatchSummary? _summaryOf(DemoMatchState match) {
    final person = demoPersonById(match.id);
    if (person == null) return null;
    final now = _clock();
    final expired = !match.expiresAt.isAfter(now);
    return MatchSummary(
      id: match.id,
      mode: match.mode,
      isSuperLike: false,
      matchedAt: match.matchedAt,
      expiresAt: match.expiresAt,
      isExpired: expired,
      extensionCount: match.extensionCount,
      isWritable: !expired,
      user: person.summaryAt(now),
      conversationId: match.id,
      lastMessageAt: match.lastMessageAt,
      lastMessagePreview: match.lastMessagePreview,
      unreadCount: match.unreadCount,
    );
  }

  DemoMatchState _find(String matchId) =>
      _inbox.find(matchId) ?? (throw _notFound);

  static const _notFound = ApiErrorException(
    code: ApiErrorCode.notFound,
    message: 'We could not find that.',
    statusCode: 404,
  );
}
