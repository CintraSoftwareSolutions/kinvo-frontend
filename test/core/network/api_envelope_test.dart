import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/network/api_envelope.dart';
import 'package:kinvo/src/core/network/api_error_code.dart';

void main() {
  group('ApiEnvelope.readData', () {
    test('rejects data that is a list rather than an object', () {
      expect(
        () => ApiEnvelope.readData({
          'success': true,
          'data': <Object?>[],
          'meta': null,
        }),
        throwsFormatException,
      );
    });

    test('does not echo the body in its error message', () {
      expect(
        () => ApiEnvelope.readData({'email': 'someone@example.com'}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            isNot(contains('someone@example.com')),
          ),
        ),
      );
    });
  });

  group('ApiEnvelope.readList', () {
    test('requires next_cursor to be present, even when it is null', () {
      expect(
        () => ApiEnvelope.readList({
          'success': true,
          'data': <Object?>[],
          'meta': {
            'pagination': {'has_more': false, 'limit': 20},
          },
        }),
        throwsFormatException,
      );
    });
  });

  group('ApiEnvelope.tryReadError', () {
    test('reads code, message and details', () {
      final error = ApiEnvelope.tryReadError({
        'success': false,
        'error': {
          'code': 'PREMIUM_REQUIRED',
          'message': 'This feature is available with Premium.',
          'details': {'required_feature': 'rewind'},
        },
      });

      expect(error?.code, ApiErrorCode.premiumRequired);
      expect(error?.message, 'This feature is available with Premium.');
      expect(error?.details, {'required_feature': 'rewind'});
    });

    test('treats non-object details as absent', () {
      final error = ApiEnvelope.tryReadError({
        'success': false,
        'error': {
          'code': 'NOT_FOUND',
          'message': 'Missing.',
          'details': 'oops',
        },
      });

      expect(error?.details, isNull);
    });

    test('returns null for bodies that are not failure envelopes', () {
      expect(ApiEnvelope.tryReadError(null), isNull);
      expect(ApiEnvelope.tryReadError('<html>502</html>'), isNull);
      expect(
        ApiEnvelope.tryReadError({
          'success': true,
          'data': <String, Object?>{},
        }),
        isNull,
      );
      expect(
        ApiEnvelope.tryReadError({
          'success': false,
          'error': {'message': 'No code.'},
        }),
        isNull,
      );
    });
  });
}
