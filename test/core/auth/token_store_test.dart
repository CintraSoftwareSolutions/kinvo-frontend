import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/auth/token_store.dart';

import '../../helpers/auth_fixtures.dart';
import '../../helpers/in_memory_key_value_store.dart';

void main() {
  late InMemoryKeyValueStore secureStore;
  late InMemoryKeyValueStore preferences;
  late TokenStore store;

  final tokens = testTokens('1', expiresAt: DateTime.utc(2026, 9, 15, 12, 30));

  setUp(() {
    secureStore = InMemoryKeyValueStore();
    preferences = InMemoryKeyValueStore();
    store = TokenStore(secureStore: secureStore, preferences: preferences);
  });

  test('returns null when nothing is saved', () async {
    expect(await store.read(), isNull);
  });

  test('reads back what it saved', () async {
    await store.write(tokens);

    expect(await store.read(), tokens);
  });

  test('discards tokens left behind by a previous installation', () async {
    await store.write(tokens);
    // Reinstalling clears preferences but, on iOS, not the Keychain.
    preferences.values.clear();

    expect(await store.read(), isNull);
    expect(secureStore.values, isEmpty);
  });

  test('discards a saved value it cannot read', () async {
    await store.write(tokens);
    secureStore.values[TokenStore.tokensKey] = '{not json';

    expect(await store.read(), isNull);
    expect(secureStore.values, isEmpty);
  });

  test('treats unreadable storage as signed out instead of throwing', () async {
    await store.write(tokens);
    secureStore.failWith = PlatformException(code: 'Failed to unwrap key');

    expect(await store.read(), isNull);
  });

  test('clear removes the tokens and the install marker', () async {
    await store.write(tokens);

    await store.clear();

    expect(secureStore.values, isEmpty);
    expect(preferences.values, isEmpty);
  });

  test('clear never throws, even when storage fails', () async {
    secureStore.failWith = PlatformException(code: 'broken');
    preferences.failWith = PlatformException(code: 'broken');

    await expectLater(store.clear(), completes);
  });

  test('write reports storage failures', () async {
    secureStore.failWith = PlatformException(code: 'broken');

    await expectLater(store.write(tokens), throwsA(isA<PlatformException>()));
  });
}
