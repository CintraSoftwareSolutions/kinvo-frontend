import 'dart:async';

// Riverpod's AsyncError would shadow the dart:async one that
// ParallelWaitError reports.
import 'package:flutter_riverpod/flutter_riverpod.dart' hide AsyncError;

import '../../../core/config/server_config.dart';
import '../../../core/config/server_config_providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';
import '../../../core/network/cursor_page.dart';
import '../../modes/data/modes_repository.dart';
import '../../modes/domain/mode_filters.dart';
import '../../modes/domain/user_modes.dart';
import '../../profile/domain/public_profile.dart';
import '../domain/deck_card.dart';
import '../domain/deck_stats.dart';
import '../domain/discovery_formatting.dart';
import '../domain/discovery_mode.dart';
import '../domain/swipe.dart';

/// Everything Discover reads from the server and sends to it. Failures are
/// `ApiException`s.
abstract interface class DiscoveryRepository {
  /// The modes the signed-in user has switched on, main mode first.
  Future<List<DiscoveryMode>> fetchModes();

  /// Saves who [mode]'s deck is built from, returning what the server holds.
  Future<ModeFilters> saveFilters(String mode, ModeFilters filters);

  /// One page of today's deck for [mode]. Pass the previous page's
  /// [CursorPage.nextCursor] to continue.
  Future<CursorPage<DeckCard>> fetchDeck(String mode, {String? cursor});

  Future<SwipeResult> swipe(
    String mode, {
    required String userId,
    required SwipeAction action,
  });

  /// Undoes the last swipe in [mode], putting that card back in the deck.
  Future<RewindResult> rewind(String mode);

  Future<DeckStats> fetchStats(String mode);

  /// Raises the user's place in other people's decks in [mode] for a while.
  Future<ActiveBoost> startBoost(String mode);

  Future<PublicProfile> fetchProfile(String userId);
}

/// [DiscoveryRepository] on the Kinvo API.
final class ApiDiscoveryRepository implements DiscoveryRepository {
  ApiDiscoveryRepository({
    required ApiClient api,
    required ModesRepository modes,
    required Future<ServerConfig> Function() config,
  }) : _api = api,
       _modes = modes,
       _config = config;

  /// Cards per page. A day's deck is at most 50, so two pages cover most
  /// days without making the first card wait for all of them.
  static const pageSize = 25;

  final ApiClient _api;
  final ModesRepository _modes;
  final Future<ServerConfig> Function() _config;

  @override
  Future<List<DiscoveryMode>> fetchModes() async {
    final (userModes, config) = await _both(_modes.fetch(), _config());
    return discoveryModesFrom(userModes, config);
  }

  @override
  Future<ModeFilters> saveFilters(String mode, ModeFilters filters) {
    return _modes.saveFilters(mode, filters);
  }

  @override
  Future<CursorPage<DeckCard>> fetchDeck(String mode, {String? cursor}) {
    return _api.getPage(
      '${_discovery(mode)}/deck',
      decodeItem: DeckCard.fromJson,
      cursor: cursor,
      limit: pageSize,
    );
  }

  @override
  Future<SwipeResult> swipe(
    String mode, {
    required String userId,
    required SwipeAction action,
  }) {
    return _api.post(
      '${_discovery(mode)}/swipe',
      body: {'target_id': userId, 'action': action.wireName},
      decode: SwipeResult.fromJson,
    );
  }

  @override
  Future<RewindResult> rewind(String mode) {
    return _api.post(
      '${_discovery(mode)}/rewind',
      decode: RewindResult.fromJson,
    );
  }

  @override
  Future<DeckStats> fetchStats(String mode) {
    return _api.get('${_discovery(mode)}/stats', decode: DeckStats.fromJson);
  }

  @override
  Future<ActiveBoost> startBoost(String mode) {
    return _api.post('${_discovery(mode)}/boost', decode: ActiveBoost.fromJson);
  }

  @override
  Future<PublicProfile> fetchProfile(String userId) {
    return _api.get(
      '/users/${Uri.encodeComponent(userId)}',
      decode: PublicProfile.fromJson,
    );
  }

  static String _discovery(String mode) {
    return '/discovery/${Uri.encodeComponent(mode)}';
  }
}

/// The switched-on modes in [userModes], main mode first and the rest in the
/// order the server's catalogue lists them, named from [config].
///
/// A mode the catalogue doesn't know, which only a server newer than its own
/// catalogue could send, is still offered, under a name made from its API
/// name and plain button labels.
List<DiscoveryMode> discoveryModesFrom(
  UserModes userModes,
  ServerConfig config,
) {
  final catalogueOrder = {
    for (final (index, option) in config.modes.indexed) option.value: index,
  };
  final options = {for (final option in config.modes) option.value: option};

  final enabled = userModes.modes.where((mode) => mode.isEnabled).toList()
    ..sort((a, b) {
      if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
      final orderA = catalogueOrder[a.mode] ?? catalogueOrder.length;
      final orderB = catalogueOrder[b.mode] ?? catalogueOrder.length;
      return orderA.compareTo(orderB);
    });

  return [
    for (final mode in enabled)
      DiscoveryMode(
        value: mode.mode,
        label: options[mode.mode]?.label ?? humanise(mode.mode),
        likeLabel: options[mode.mode]?.likeLabel ?? 'Like',
        superLikeLabel: options[mode.mode]?.superLikeLabel ?? 'Super Like',
        isPrimary: mode.isPrimary,
        filters: mode.filters,
      ),
  ];
}

/// Waits for both, failing with whichever failed first rather than with the
/// [ParallelWaitError] that hides it.
Future<(A, B)> _both<A, B>(Future<A> a, Future<B> b) async {
  try {
    return await (a, b).wait;
  } on ParallelWaitError<(A?, B?), (AsyncError?, AsyncError?)> catch (error) {
    final (errorA, errorB) = error.errors;
    final first = (errorA ?? errorB)!;
    Error.throwWithStackTrace(first.error, first.stackTrace);
  }
}

/// The repository Discover uses.
final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  return ApiDiscoveryRepository(
    api: ref.watch(apiClientProvider),
    modes: ref.watch(modesRepositoryProvider),
    config: () => ref.read(serverConfigProvider.future),
  );
});
