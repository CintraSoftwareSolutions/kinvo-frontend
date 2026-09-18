/// Machine-readable error codes from the backend's error envelope.
///
/// The code, not the HTTP status or the message, is the contract to branch on.
/// The server may add codes without an app release, so anything unrecognised
/// becomes [unknown] instead of failing to parse.
enum ApiErrorCode {
  validationFailed('VALIDATION_FAILED'),
  badRequest('BAD_REQUEST'),

  /// No access token was sent. Send the user to sign in.
  authRequired('AUTH_REQUIRED'),

  /// The access token expired, which is routine. Refresh it and retry.
  authTokenExpired('AUTH_TOKEN_EXPIRED'),

  /// The session is no longer valid. Sign the user out.
  authTokenInvalid('AUTH_TOKEN_INVALID'),
  authInvalidCredentials('AUTH_INVALID_CREDENTIALS'),

  forbidden('FORBIDDEN'),
  onboardingIncomplete('ONBOARDING_INCOMPLETE'),
  accountSuspended('ACCOUNT_SUSPENDED'),

  /// The feature needs a paid tier. `details` carries the paywall context.
  premiumRequired('PREMIUM_REQUIRED'),
  userBlocked('USER_BLOCKED'),

  /// Also returned when a block or deletion is the reason, so it must be
  /// handled the same way as a resource that never existed.
  notFound('NOT_FOUND'),
  conflict('CONFLICT'),

  fileTooLarge('FILE_TOO_LARGE'),
  unsupportedMediaType('UNSUPPORTED_MEDIA_TYPE'),

  /// A daily limit was reached. `details` carries the paywall context.
  quotaExceeded('QUOTA_EXCEEDED'),
  rateLimited('RATE_LIMITED'),

  internalError('INTERNAL_ERROR'),
  serviceUnavailable('SERVICE_UNAVAILABLE'),

  /// A code this version of the app doesn't know yet.
  unknown('UNKNOWN');

  const ApiErrorCode(this.wireValue);

  /// The value as it appears in `error.code`.
  final String wireValue;

  static final Map<String, ApiErrorCode> _byWireValue = {
    for (final code in values) code.wireValue: code,
  };

  static ApiErrorCode fromWireValue(String value) =>
      _byWireValue[value] ?? unknown;
}
