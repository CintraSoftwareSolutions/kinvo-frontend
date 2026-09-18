import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';
import '../domain/mode_filters.dart';
import '../domain/user_modes.dart';

/// Reads and switches the signed-in user's modes.
final class ModesRepository {
  const ModesRepository(this._api);

  final ApiClient _api;

  Future<UserModes> fetch() {
    return _api.get('/modes', decode: UserModes.fromJson);
  }

  /// Switches [mode] on or off. The first mode switched on becomes the main
  /// mode.
  Future<void> setEnabled(String mode, {required bool enabled}) {
    return _api.patch(
      '/modes/${Uri.encodeComponent(mode)}',
      body: {'is_enabled': enabled},
      decode: ApiClient.ignoreData,
    );
  }

  /// Makes [mode], which must be on, the main mode.
  Future<UserModes> makePrimary(String mode) {
    return _api.post(
      '/modes/${Uri.encodeComponent(mode)}/primary',
      decode: UserModes.fromJson,
    );
  }

  /// Saves who [mode]'s deck is built from, and returns the filters the
  /// server now holds.
  ///
  /// The server rebuilds today's deck for the mode, so the change shows on the
  /// next read of the deck rather than tomorrow.
  Future<ModeFilters> saveFilters(String mode, ModeFilters filters) {
    return _api.patch(
      '/modes/${Uri.encodeComponent(mode)}',
      body: filters.toJson(),
      decode: (json) =>
          UserMode.tryFromJson(json)?.filters ??
          (throw const FormatException('Expected a mode with its filters.')),
    );
  }
}

final modesRepositoryProvider = Provider<ModesRepository>(
  (ref) => ModesRepository(ref.watch(apiClientProvider)),
);
