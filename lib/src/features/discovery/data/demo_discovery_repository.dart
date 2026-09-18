import '../../../core/network/api_error_code.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/cursor_page.dart';
import '../../../core/time/clock.dart';
import '../../modes/domain/mode_filters.dart';
import '../../profile/domain/public_profile.dart';
import '../domain/deck_card.dart';
import '../domain/deck_stats.dart';
import '../domain/discovery_mode.dart';
import '../domain/swipe.dart';
import 'demo_people.dart';
import 'discovery_repository.dart';

/// Discover for the demo: sample people, kept in memory, with no account and
/// no connection needed.
///
/// It keeps the rules the server keeps where they show — a swiped card stays
/// gone, filters change the deck, rewind brings back the last card, a boost
/// can't run twice — so the demo behaves like the real thing.
final class DemoDiscoveryRepository implements DiscoveryRepository {
  DemoDiscoveryRepository({required Clock clock}) : _clock = clock;

  static const _modes = [
    ('dating', 'Dating', 'Like', 'Super Like'),
    ('study_buddy', 'Study Buddy', 'Study', 'Invite'),
    ('networking', 'Networking', 'Connect', 'Intro'),
    ('trading', 'Trading', 'Trade', 'Signal'),
    ('foodie', 'Foodie', 'Taste', 'Table'),
    ('cuddle', 'Cuddle', 'Cozy', 'Warmth'),
    ('pet_dates', 'Pet Dates', 'Paw', 'Playdate'),
    ('fitness', 'Fitness', 'Fitness', 'Train'),
  ];

  static const _defaultFilters = ModeFilters(
    minAge: ModeFilters.youngestAge,
    maxAge: ModeFilters.oldestAge,
    radiusMetres: 48280,
    verifiedOnly: false,
  );

  static const _boostLength = Duration(minutes: 30);

  final Clock _clock;
  final Map<String, ModeFilters> _filters = {};
  final Map<String, List<(String userId, SwipeAction action)>> _swipes = {};
  final Map<String, Set<String>> _matches = {};
  final Map<String, ActiveBoost> _boosts = {};

  @override
  Future<List<DiscoveryMode>> fetchModes() async {
    return [
      for (final (value, label, likeLabel, superLikeLabel) in _modes)
        DiscoveryMode(
          value: value,
          label: label,
          likeLabel: likeLabel,
          superLikeLabel: superLikeLabel,
          isPrimary: value == 'dating',
          filters: _filters[value] ?? _defaultFilters,
        ),
    ];
  }

  @override
  Future<ModeFilters> saveFilters(String mode, ModeFilters filters) async {
    _filters[mode] = filters;
    return filters;
  }

  @override
  Future<CursorPage<DeckCard>> fetchDeck(String mode, {String? cursor}) async {
    final now = _clock();
    final cards = [
      for (final (index, person) in _deckFor(mode).indexed)
        DeckCard(
          entryId: 'demo-$mode-${person.id}',
          position: index,
          distanceMetres: person.distanceMetres,
          user: person.summaryAt(now),
          bio: person.bio,
          interestSlugs: person.interests,
        ),
    ];
    return CursorPage(
      items: cards,
      nextCursor: null,
      hasMore: false,
      limit: cards.length,
    );
  }

  @override
  Future<SwipeResult> swipe(
    String mode, {
    required String userId,
    required SwipeAction action,
  }) async {
    final person = demoPersonById(userId);
    final swipes = _swipes.putIfAbsent(mode, () => []);
    if (person == null || swipes.any((swipe) => swipe.$1 == userId)) {
      throw const ApiErrorException(
        code: ApiErrorCode.conflict,
        message: 'You have already swiped on this person in this mode.',
        statusCode: 409,
      );
    }
    swipes.add((userId, action));

    final matched = action.usesAllowance && person.likesBack;
    if (matched) _matches.putIfAbsent(mode, () => {}).add(userId);

    return SwipeResult(
      action: action,
      match: matched
          ? NewMatch(
              id: 'demo-match-$mode-$userId',
              mode: mode,
              isSuperLike: action == SwipeAction.superLike,
              matchedAt: _clock(),
            )
          : null,
      allowance: SwipeAllowance.unlimited,
    );
  }

  @override
  Future<RewindResult> rewind(String mode) async {
    final swipes = _swipes[mode];
    if (swipes == null || swipes.isEmpty) {
      throw const ApiErrorException(
        code: ApiErrorCode.notFound,
        message: 'There is nothing to rewind in this mode.',
        statusCode: 404,
      );
    }
    final (userId, action) = swipes.removeLast();
    final matchRemoved = _matches[mode]?.remove(userId) ?? false;
    return RewindResult(
      restoredUserId: userId,
      action: action,
      matchRemoved: matchRemoved,
    );
  }

  @override
  Future<DeckStats> fetchStats(String mode) async {
    final swipes = _swipes[mode] ?? const [];
    int count(SwipeAction action) {
      return swipes.where((swipe) => swipe.$2 == action).length;
    }

    final boost = _boosts[mode];
    return DeckStats(
      mode: mode,
      liked: count(SwipeAction.like),
      passed: count(SwipeAction.pass),
      superLiked: count(SwipeAction.superLike),
      matches: _matches[mode]?.length ?? 0,
      likesReceived: 2,
      cardsRemaining: _deckFor(mode).length,
      boost: boost != null && boost.isActiveAt(_clock()) ? boost : null,
      allowance: SwipeAllowance.unlimited,
    );
  }

  @override
  Future<ActiveBoost> startBoost(String mode) async {
    final now = _clock();
    if (_boosts[mode] case final running? when running.isActiveAt(now)) {
      throw ApiErrorException(
        code: ApiErrorCode.conflict,
        message: 'A boost is already running in this mode.',
        statusCode: 409,
        details: {'ends_at': running.endsAt.toIso8601String()},
      );
    }
    return _boosts[mode] = ActiveBoost(
      id: 'demo-boost-$mode',
      mode: mode,
      startedAt: now,
      endsAt: now.add(_boostLength),
    );
  }

  @override
  Future<PublicProfile> fetchProfile(String userId) async {
    final person = demoPersonById(userId);
    if (person == null) {
      throw const ApiErrorException(
        code: ApiErrorCode.notFound,
        message: 'We could not find that.',
        statusCode: 404,
      );
    }
    return person.profileAt(_clock());
  }

  /// [mode]'s deck: its own sample person first, then everyone else, less
  /// anyone already swiped on or outside the filters.
  List<DemoPerson> _deckFor(String mode) {
    final filters = _filters[mode] ?? _defaultFilters;
    final swiped = {
      for (final (userId, _) in _swipes[mode] ?? const []) userId,
    };
    return [
      ...demoPeople.where((person) => person.homeMode == mode),
      ...demoPeople.where((person) => person.homeMode != mode),
    ].where((person) {
      return !swiped.contains(person.id) &&
          person.age >= filters.minAge &&
          person.age <= filters.maxAge &&
          person.distanceMetres <= filters.radiusMetres &&
          (!filters.verifiedOnly || person.isVerified);
    }).toList();
  }
}
