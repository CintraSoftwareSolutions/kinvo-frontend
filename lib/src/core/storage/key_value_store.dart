import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// String storage behind an interface, so the code deciding what to store can
/// be tested without platform channels.
abstract interface class KeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// Encrypted storage: the Keychain on iOS, Keystore-backed encryption on
/// Android. Use it for credentials.
final class SecureKeyValueStore implements KeyValueStore {
  const SecureKeyValueStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Plain app preferences. Unlike the iOS Keychain, they're removed when the
/// app is uninstalled.
final class PreferencesKeyValueStore implements KeyValueStore {
  const PreferencesKeyValueStore(this._preferences);

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) {
    return _preferences.setString(key, value);
  }

  @override
  Future<void> delete(String key) => _preferences.remove(key);
}
