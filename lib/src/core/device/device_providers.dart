import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/storage_providers.dart';
import 'client_info.dart';

/// This installation's identity, loaded once per app run.
final clientInfoProvider = FutureProvider<ClientInfo>((ref) {
  return ClientInfoLoader(
    preferences: ref.watch(preferencesKeyValueStoreProvider),
  ).load();
});
