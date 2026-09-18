import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/network/api_error_code.dart';

void main() {
  // Mirrors kinvo-backend/src/utils/error-codes.ts. A code missing here
  // would reach the app as `unknown` and skip its specific handling.
  const backendCodes = [
    'VALIDATION_FAILED',
    'BAD_REQUEST',
    'AUTH_REQUIRED',
    'AUTH_TOKEN_EXPIRED',
    'AUTH_TOKEN_INVALID',
    'AUTH_INVALID_CREDENTIALS',
    'FORBIDDEN',
    'ONBOARDING_INCOMPLETE',
    'ACCOUNT_SUSPENDED',
    'PREMIUM_REQUIRED',
    'USER_BLOCKED',
    'NOT_FOUND',
    'CONFLICT',
    'FILE_TOO_LARGE',
    'UNSUPPORTED_MEDIA_TYPE',
    'QUOTA_EXCEEDED',
    'RATE_LIMITED',
    'INTERNAL_ERROR',
    'SERVICE_UNAVAILABLE',
  ];

  test('recognises every code the backend sends', () {
    for (final wireValue in backendCodes) {
      final code = ApiErrorCode.fromWireValue(wireValue);

      expect(code, isNot(ApiErrorCode.unknown), reason: wireValue);
      expect(code.wireValue, wireValue);
    }
  });

  test('maps codes it does not know to unknown', () {
    expect(ApiErrorCode.fromWireValue('NEW_CODE'), ApiErrorCode.unknown);
    expect(ApiErrorCode.fromWireValue(''), ApiErrorCode.unknown);
  });
}
