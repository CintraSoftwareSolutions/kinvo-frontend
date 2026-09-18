import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/auth/auth_tokens.dart';

void main() {
  final receivedAt = DateTime.utc(2026, 9, 15, 12);

  group('AuthTokens.fromResponse', () {
    test('measures expiry from when the response arrived', () {
      final tokens = AuthTokens.fromResponse({
        'access_token': 'access',
        'refresh_token': 'refresh',
        'token_type': 'Bearer',
        'expires_in': 1800,
      }, receivedAt: receivedAt);

      expect(tokens.accessToken, 'access');
      expect(tokens.refreshToken, 'refresh');
      expect(tokens.accessTokenExpiresAt, DateTime.utc(2026, 9, 15, 12, 30));
    });

    final invalid = <String, Map<String, Object?>>{
      'another token type': {
        'access_token': 'access',
        'refresh_token': 'refresh',
        'token_type': 'MAC',
        'expires_in': 1800,
      },
      'a non-positive lifetime': {
        'access_token': 'access',
        'refresh_token': 'refresh',
        'token_type': 'Bearer',
        'expires_in': 0,
      },
      'an empty refresh token': {
        'access_token': 'access',
        'refresh_token': '',
        'token_type': 'Bearer',
        'expires_in': 1800,
      },
      'a missing access token': {
        'refresh_token': 'refresh',
        'token_type': 'Bearer',
        'expires_in': 1800,
      },
    };

    for (final MapEntry(key: description, value: json) in invalid.entries) {
      test('rejects $description', () {
        expect(
          () => AuthTokens.fromResponse(json, receivedAt: receivedAt),
          throwsFormatException,
        );
      });
    }
  });

  group('expiresWithin', () {
    final tokens = AuthTokens(
      accessToken: 'access',
      refreshToken: 'refresh',
      accessTokenExpiresAt: DateTime.utc(2026, 9, 15, 12, 30),
    );

    test('is false while the token is valid for longer than the margin', () {
      expect(
        tokens.expiresWithin(
          const Duration(minutes: 1),
          now: DateTime.utc(2026, 9, 15, 12, 28),
        ),
        isFalse,
      );
    });

    test('is true once the margin reaches the expiry', () {
      expect(
        tokens.expiresWithin(
          const Duration(minutes: 1),
          now: DateTime.utc(2026, 9, 15, 12, 29),
        ),
        isTrue,
      );
    });

    test('compares in UTC whatever the clock time zone', () {
      final localNow = DateTime.utc(2026, 9, 15, 12, 31).toLocal();

      expect(tokens.expiresWithin(Duration.zero, now: localNow), isTrue);
    });
  });

  group('storage form', () {
    final tokens = AuthTokens(
      accessToken: 'access',
      refreshToken: 'refresh',
      accessTokenExpiresAt: DateTime.utc(2026, 9, 15, 12, 30),
    );

    test('round-trips', () {
      expect(AuthTokens.tryFromStorageJson(tokens.toStorageJson()), tokens);
    });

    test('ignores values from an unknown storage version', () {
      final json = {...tokens.toStorageJson(), 'version': 99};

      expect(AuthTokens.tryFromStorageJson(json), isNull);
    });

    test('ignores values with an unreadable expiry', () {
      final json = {
        ...tokens.toStorageJson(),
        'access_token_expires_at': 'soon',
      };

      expect(AuthTokens.tryFromStorageJson(json), isNull);
    });
  });

  test('toString never includes the tokens', () {
    final tokens = AuthTokens(
      accessToken: 'secret-access',
      refreshToken: 'secret-refresh',
      accessTokenExpiresAt: DateTime.utc(2026, 9, 15, 12, 30),
    );

    expect(tokens.toString(), isNot(contains('secret')));
  });
}
