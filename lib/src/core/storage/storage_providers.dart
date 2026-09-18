import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'key_value_store.dart';

/// Where credentials are kept.
///
/// iOS: readable once the device has been unlocked after a restart, so
/// background work can use it, and never restored onto another device.
/// Android: the package's default AES-GCM storage with a Keystore-wrapped key.
/// App backups are disabled in the manifest because restored ciphertext can't
/// be decrypted on a different device.
final secureKeyValueStoreProvider = Provider<KeyValueStore>((ref) {
  return const SecureKeyValueStore(
    FlutterSecureStorage(
      aOptions: AndroidOptions(),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    ),
  );
});

/// App preferences for non-secret values.
final preferencesKeyValueStoreProvider = Provider<KeyValueStore>((ref) {
  return PreferencesKeyValueStore(SharedPreferencesAsync());
});
