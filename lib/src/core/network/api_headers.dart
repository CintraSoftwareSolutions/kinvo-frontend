/// Names of the HTTP headers the API client reads or sends.
abstract final class ApiHeaders {
  /// `Bearer <access token>` on requests made with a session.
  static const authorization = 'authorization';

  /// This installation's id. Sessions and push tokens are tied to it.
  static const deviceId = 'x-device-id';

  /// `android` or `ios`.
  static const platform = 'x-platform';

  static const appVersion = 'x-app-version';

  /// Such as "Google Pixel 8". Labels the device in the device list.
  static const deviceModel = 'x-device-model';

  /// Such as "Android 15". Labels the device in the device list.
  static const osVersion = 'x-os-version';

  static const acceptLanguage = 'accept-language';

  /// Correlation id the server returns on every response.
  static const requestId = 'x-request-id';

  /// Seconds to wait before retrying a rate-limited request.
  static const retryAfter = 'retry-after';
}
