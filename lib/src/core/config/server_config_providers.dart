import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/network_providers.dart';
import 'server_config.dart';

/// Reads the server's catalogue. Needs no session: the app can show it before
/// anyone signs in.
final class ServerConfigRepository {
  const ServerConfigRepository(this._api);

  final ApiClient _api;

  Future<ServerConfig> fetch() {
    return _api.get('/config', decode: ServerConfig.fromJson);
  }
}

final serverConfigRepositoryProvider = Provider<ServerConfigRepository>(
  (ref) => ServerConfigRepository(ref.watch(publicApiClientProvider)),
);

/// The server's catalogue, loaded once per app run.
final serverConfigProvider = FutureProvider<ServerConfig>(
  (ref) => ref.watch(serverConfigRepositoryProvider).fetch(),
);
