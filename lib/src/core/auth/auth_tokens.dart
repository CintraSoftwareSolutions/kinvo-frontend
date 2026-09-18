import 'package:flutter/foundation.dart';

import '../network/api_envelope.dart';

/// The access and refresh tokens of a signed-in session.
@immutable
final class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
  });

  /// Reads the token pair returned by the sign-in and refresh endpoints:
  /// `{ access_token, refresh_token, token_type: "Bearer", expires_in }`.
  ///
  /// The expiry is measured from [receivedAt] on this device's clock rather
  /// than read from the token, so a wrong device clock can't make a fresh
  /// token look expired.
  factory AuthTokens.fromResponse(
    JsonMap json, {
    required DateTime receivedAt,
  }) {
    if (json
        case {
          'access_token': final String accessToken,
          'refresh_token': final String refreshToken,
          'token_type': 'Bearer',
          'expires_in': final int expiresInSeconds,
        }
        when accessToken.isNotEmpty &&
            refreshToken.isNotEmpty &&
            expiresInSeconds > 0) {
      return AuthTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        accessTokenExpiresAt: receivedAt.toUtc().add(
          Duration(seconds: expiresInSeconds),
        ),
      );
    }
    throw const FormatException(
      'Expected access_token, refresh_token, token_type "Bearer" and a '
      'positive expires_in.',
    );
  }

  static const _storageVersion = 1;

  final String accessToken;

  /// Single use: the server replaces it on every refresh.
  final String refreshToken;

  /// When the server stops accepting [accessToken], in UTC.
  final DateTime accessTokenExpiresAt;

  /// Whether [accessToken] expires within [margin] of [now].
  bool expiresWithin(Duration margin, {required DateTime now}) {
    return !now.toUtc().add(margin).isBefore(accessTokenExpiresAt);
  }

  /// The form saved to secure storage.
  JsonMap toStorageJson() {
    return {
      'version': _storageVersion,
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'access_token_expires_at': accessTokenExpiresAt.toIso8601String(),
    };
  }

  /// Reads a value written by [toStorageJson], or returns `null` when it's
  /// missing, corrupt or from an unknown storage version.
  static AuthTokens? tryFromStorageJson(Object? json) {
    if (json case {
      'version': _storageVersion,
      'access_token': final String accessToken,
      'refresh_token': final String refreshToken,
      'access_token_expires_at': final String expiresAt,
    } when accessToken.isNotEmpty && refreshToken.isNotEmpty) {
      final parsedExpiry = DateTime.tryParse(expiresAt);
      if (parsedExpiry != null) {
        return AuthTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
          accessTokenExpiresAt: parsedExpiry.toUtc(),
        );
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    return other is AuthTokens &&
        other.accessToken == accessToken &&
        other.refreshToken == refreshToken &&
        other.accessTokenExpiresAt == accessTokenExpiresAt;
  }

  @override
  int get hashCode =>
      Object.hash(accessToken, refreshToken, accessTokenExpiresAt);

  /// Never includes the tokens themselves, so logging a session can't leak it.
  @override
  String toString() => 'AuthTokens(expiresAt: $accessTokenExpiresAt)';
}
