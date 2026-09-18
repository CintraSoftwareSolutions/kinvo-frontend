import 'package:flutter/foundation.dart';

/// Settings compiled into the app at build time.
///
/// Supply them with `--dart-define-from-file=env/<environment>.json`. The
/// values end up inside the binary, so nothing secret belongs here.
@immutable
final class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  /// Reads the values passed at build time.
  ///
  /// Throws [AppConfigException] when a value is missing or malformed, so a
  /// misconfigured build fails on its first request instead of quietly talking
  /// to the wrong server.
  factory AppConfig.fromEnvironment() {
    return AppConfig(
      apiBaseUrl: parseApiBaseUrl(const String.fromEnvironment(apiBaseUrlKey)),
    );
  }

  static const apiBaseUrlKey = 'API_BASE_URL';

  /// Hosts that may be reached over plain HTTP while developing against a
  /// local backend. `10.0.2.2` is the host machine as seen from the Android
  /// emulator.
  static const _localHosts = {'localhost', '127.0.0.1', '10.0.2.2'};

  /// Root of the versioned REST API without a trailing slash, for example
  /// `https://api.example.com/api/v1`.
  final Uri apiBaseUrl;

  /// Validates [raw] and normalises it for use as the HTTP client's base URL.
  @visibleForTesting
  static Uri parseApiBaseUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      throw const AppConfigException(
        '$apiBaseUrlKey is not set. Run the app with '
        '--dart-define-from-file=env/staging.json.',
      );
    }

    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw AppConfigException(
        '$apiBaseUrlKey must be an absolute URL, but was "$value".',
      );
    }
    if (uri.hasQuery || uri.hasFragment) {
      throw AppConfigException(
        '$apiBaseUrlKey must not contain a query or fragment, but was "$value".',
      );
    }

    if (!isSecureOrLocal(uri)) {
      throw AppConfigException(
        '$apiBaseUrlKey must use https (plain http is only allowed for '
        'local development hosts), but was "$value".',
      );
    }

    // Request paths start with "/" and the HTTP client joins them to the base
    // URL by concatenation, so the base must not end with one.
    return uri.replace(path: uri.path.replaceFirst(RegExp(r'/+$'), ''));
  }

  /// Whether the app may send traffic to [uri]: over https, or over plain http
  /// to a local development host only.
  static bool isSecureOrLocal(Uri uri) {
    return uri.scheme == 'https' ||
        (uri.scheme == 'http' && _localHosts.contains(uri.host));
  }
}

/// Thrown when build-time configuration is missing or invalid.
final class AppConfigException implements Exception {
  const AppConfigException(this.message);

  final String message;

  @override
  String toString() => 'AppConfigException: $message';
}
