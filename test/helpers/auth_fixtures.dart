import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/auth/auth_api.dart';
import 'package:kinvo/src/core/auth/auth_tokens.dart';
import 'package:kinvo/src/core/auth/session_manager.dart';
import 'package:kinvo/src/core/auth/token_store.dart';
import 'package:kinvo/src/core/config/app_config.dart';
import 'package:kinvo/src/core/network/api_client.dart';
import 'package:kinvo/src/core/network/api_dio.dart';

import 'fake_http_adapter.dart';
import 'in_memory_key_value_store.dart';

final testConfig = AppConfig(apiBaseUrl: Uri.parse('https://api.test/api/v1'));

/// A clock tests can move.
final class FakeClock {
  FakeClock(this.now);

  DateTime now;

  DateTime call() => now;
}

/// Tokens named after [name], e.g. `access-1` and `refresh-1`.
AuthTokens testTokens(String name, {required DateTime expiresAt}) {
  return AuthTokens(
    accessToken: 'access-$name',
    refreshToken: 'refresh-$name',
    accessTokenExpiresAt: expiresAt,
  );
}

/// The success envelope of a sign-in or refresh response.
Map<String, Object?> tokenPairEnvelope(String name, {int expiresIn = 1800}) {
  return successEnvelope({
    'access_token': 'access-$name',
    'refresh_token': 'refresh-$name',
    'token_type': 'Bearer',
    'expires_in': expiresIn,
  });
}

/// The `Bearer` token a request was sent with, if any.
String? sentBearerToken(RequestOptions options) {
  final header = options.headers['authorization'];
  return header is String ? header.replaceFirst('Bearer ', '') : null;
}

/// Lets queued microtasks and zero-duration timers run, for work started
/// without being awaited.
Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// A [SessionManager] wired to in-memory storage and a fake server.
final class SessionHarness {
  SessionHarness({required FakeResponder respond, DateTime? now})
    : clock = FakeClock(now ?? DateTime.utc(2026, 9, 15, 12)) {
    adapter = FakeHttpAdapter(respond);
    publicDio = createApiDio(testConfig)..httpClientAdapter = adapter;
    addTearDown(publicDio.close);
  }

  final FakeClock clock;
  final secureStore = InMemoryKeyValueStore();
  final preferences = InMemoryKeyValueStore();
  late final FakeHttpAdapter adapter;
  late final Dio publicDio;

  late final TokenStore store = TokenStore(
    secureStore: secureStore,
    preferences: preferences,
  );

  /// Saves [tokens] as if a previous launch had signed in.
  Future<void> saveSession(AuthTokens tokens) => store.write(tokens);

  SessionManager createManager() {
    final manager = SessionManager(
      store: store,
      api: AuthApi(ApiClient(publicDio), clock: clock.call),
      clock: clock.call,
    );
    addTearDown(manager.dispose);
    return manager;
  }

  Iterable<RequestOptions> requestsTo(String path) {
    return adapter.requests.where((r) => r.uri.path == '/api/v1$path');
  }
}
