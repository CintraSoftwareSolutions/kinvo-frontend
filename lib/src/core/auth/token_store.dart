import 'dart:convert';
import 'dart:developer' as developer;

import '../storage/key_value_store.dart';
import 'auth_tokens.dart';

/// Saves the session's tokens between launches.
final class TokenStore {
  TokenStore({
    required KeyValueStore secureStore,
    required KeyValueStore preferences,
  }) : _secureStore = secureStore,
       _preferences = preferences;

  static const tokensKey = 'kinvo.auth.tokens';

  /// Set in preferences whenever tokens are saved. Preferences are deleted on
  /// uninstall but the iOS Keychain isn't, so tokens without this marker were
  /// left behind by a previous installation.
  static const savedByThisInstallKey = 'kinvo.auth.saved_by_this_install';

  final KeyValueStore _secureStore;
  final KeyValueStore _preferences;

  /// Returns the saved tokens, or `null` when there are none.
  ///
  /// Never throws. Unreadable, corrupt or leftover tokens count as signed out
  /// and are removed: a user can always sign in again, but an app that can't
  /// read its own storage would otherwise fail on every launch.
  Future<AuthTokens?> read() async {
    try {
      final raw = await _secureStore.read(tokensKey);
      if (raw == null) return null;

      if (await _preferences.read(savedByThisInstallKey) == null) {
        _log('Discarding tokens left by a previous installation.');
        await clear();
        return null;
      }

      final tokens = AuthTokens.tryFromStorageJson(jsonDecode(raw));
      if (tokens == null) {
        _log('Discarding saved tokens that could not be read.');
        await clear();
      }
      return tokens;
    } on Object catch (error, stackTrace) {
      _log('Could not read the saved session.', error, stackTrace);
      await clear();
      return null;
    }
  }

  /// Saves [tokens], replacing any saved before.
  ///
  /// Throws when storage fails. The session still works for this run, but the
  /// user will have to sign in again next launch.
  Future<void> write(AuthTokens tokens) async {
    // Marker first: if saving the tokens then fails, read() finds no tokens,
    // which is the same outcome as never having saved them.
    await _preferences.write(savedByThisInstallKey, 'true');
    await _secureStore.write(tokensKey, jsonEncode(tokens.toStorageJson()));
  }

  /// Removes the saved tokens. Never throws, so signing out always succeeds
  /// on the device.
  Future<void> clear() async {
    try {
      await _secureStore.delete(tokensKey);
    } on Object catch (error, stackTrace) {
      _log('Could not delete the saved session.', error, stackTrace);
    }
    try {
      await _preferences.delete(savedByThisInstallKey);
    } on Object catch (error, stackTrace) {
      _log('Could not delete the session marker.', error, stackTrace);
    }
  }

  static void _log(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: 'kinvo.auth',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
