import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/network_providers.dart';
import '../storage/storage_providers.dart';
import '../time/clock.dart';
import 'auth_api.dart';
import 'session_manager.dart';
import 'session_status.dart';
import 'token_store.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) {
  return TokenStore(
    secureStore: ref.watch(secureKeyValueStoreProvider),
    preferences: ref.watch(preferencesKeyValueStoreProvider),
  );
});

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(
    ref.watch(publicApiClientProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// The single owner of the session. Starts reading saved tokens as soon as
/// it's first used.
final sessionManagerProvider = Provider<SessionManager>((ref) {
  final manager = SessionManager(
    store: ref.watch(tokenStoreProvider),
    api: ref.watch(authApiProvider),
    clock: ref.watch(clockProvider),
  );
  ref.onDispose(manager.dispose);
  return manager;
});

/// The session's status, for widgets. Routing can listen to
/// `SessionManager.status` directly.
final sessionStatusProvider =
    NotifierProvider<SessionStatusNotifier, SessionStatus>(
      SessionStatusNotifier.new,
    );

class SessionStatusNotifier extends Notifier<SessionStatus> {
  @override
  SessionStatus build() {
    final status = ref.watch(sessionManagerProvider).status;
    void update() => state = status.value;
    status.addListener(update);
    ref.onDispose(() => status.removeListener(update));
    return status.value;
  }
}
