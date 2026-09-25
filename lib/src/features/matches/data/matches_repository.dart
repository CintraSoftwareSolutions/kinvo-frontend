import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';
import '../../../core/network/cursor_page.dart';
import '../domain/match_summary.dart';

/// Everything the Matches tab reads from the server and sends to it.
/// Failures are `ApiException`s.
abstract interface class MatchesRepository {
  /// One page of matches, newest first. [archived] picks the Archived tab.
  Future<CursorPage<MatchSummary>> fetchMatches({
    required bool archived,
    String? cursor,
  });

  /// One match, whether current, archived or expired. Fails with `NOT_FOUND`
  /// once it has ended, which covers being blocked too.
  Future<MatchSummary> fetchMatch(String matchId);

  /// One page of the people waiting for an answer in [mode], newest first.
  /// Part of a paid plan: without one, this fails with `PREMIUM_REQUIRED`.
  Future<CursorPage<LikeReceived>> fetchLikes(String mode, {String? cursor});

  /// Ends the match for both people. It can't be undone.
  Future<void> unmatch(String matchId);

  /// Gives the match more time before it lapses. Part of a paid plan.
  Future<MatchSummary> extend(String matchId);
}

/// [MatchesRepository] on the Kinvo API.
final class ApiMatchesRepository implements MatchesRepository {
  const ApiMatchesRepository(this._api);

  static const pageSize = 20;

  final ApiClient _api;

  @override
  Future<CursorPage<MatchSummary>> fetchMatches({
    required bool archived,
    String? cursor,
  }) {
    return _api.getPage(
      '/matches',
      decodeItem: MatchSummary.fromJson,
      cursor: cursor,
      limit: pageSize,
      query: {if (archived) 'archived': 'true'},
    );
  }

  @override
  Future<MatchSummary> fetchMatch(String matchId) {
    return _api.get(
      '/matches/${Uri.encodeComponent(matchId)}',
      decode: MatchSummary.fromJson,
    );
  }

  @override
  Future<CursorPage<LikeReceived>> fetchLikes(String mode, {String? cursor}) {
    return _api.getPage(
      '/discovery/${Uri.encodeComponent(mode)}/likes-you',
      decodeItem: LikeReceived.fromJson,
      cursor: cursor,
      limit: pageSize,
    );
  }

  @override
  Future<void> unmatch(String matchId) {
    return _api.delete(
      '/matches/${Uri.encodeComponent(matchId)}',
      decode: ApiClient.ignoreData,
    );
  }

  @override
  Future<MatchSummary> extend(String matchId) {
    return _api.post(
      '/matches/${Uri.encodeComponent(matchId)}/extend',
      decode: MatchSummary.fromJson,
    );
  }
}

/// The repository the Matches tab uses.
final matchesRepositoryProvider = Provider<MatchesRepository>(
  (ref) => ApiMatchesRepository(ref.watch(apiClientProvider)),
);
