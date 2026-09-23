import 'package:flutter/foundation.dart';

import '../network/api_client.dart';
import '../network/api_envelope.dart';
import '../time/calendar_date.dart';
import 'auth_tokens.dart';

/// The auth endpoints that work without a session: creating an account,
/// signing in, and refreshing or revoking tokens.
///
/// Uses a client without the auth interceptor, so refreshing a token can never
/// trigger another refresh.
final class AuthApi {
  AuthApi(this._client, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final ApiClient _client;
  final DateTime Function() _clock;

  /// Creates an account and returns the tokens of its first session.
  ///
  /// [deviceId] ties the session to this installation, so it can be found and
  /// revoked in the account's device list.
  Future<AuthTokens> register({
    required String displayName,
    required String email,
    required String password,
    required CalendarDate dateOfBirth,
    required String deviceId,
  }) {
    return _client.post(
      '/auth/register',
      body: {
        'display_name': displayName,
        'email': email,
        'password': password,
        'date_of_birth': dateOfBirth.toIsoString(),
        'device_id': deviceId,
      },
      decode: _readTokens,
    );
  }

  /// Signs in with an email address and password.
  Future<AuthTokens> login({
    required String email,
    required String password,
    required String deviceId,
  }) {
    return _client.post(
      '/auth/login',
      body: {'email': email, 'password': password, 'device_id': deviceId},
      decode: _readTokens,
    );
  }

  /// Sends a sign-in code by SMS to [phone], in international format.
  ///
  /// Succeeds whether or not the number has an account: the server answers
  /// identically either way, so nobody can use this to find out who has one.
  /// The code itself is never returned — Twilio holds it, and the only way to
  /// prove it arrived is to send it back in [verifyPhone].
  Future<void> sendPhoneCode({required String phone}) {
    return _client.post(
      '/auth/otp/send',
      body: {'phone': phone},
      decode: ApiClient.ignoreData,
    );
  }

  /// Signs in with the code sent to [phone], creating the account if that
  /// number has none.
  ///
  /// [displayName] is used only for a number that has never signed in before;
  /// the server ignores it for an existing account, so a returning user cannot
  /// have their name changed by a sign-in.
  Future<SignInResult> verifyPhone({
    required String phone,
    required String code,
    required String deviceId,
    String? displayName,
  }) {
    return _client.post(
      '/auth/otp/verify',
      body: {
        'phone': phone,
        'code': code,
        'device_id': deviceId,
        if (displayName != null && displayName.trim().isNotEmpty)
          'display_name': displayName.trim(),
      },
      decode: (json) => SignInResult(
        tokens: _readTokens(json),
        // A new account has no date of birth yet, and the app must not let it
        // past onboarding without one.
        isNewUser: json['is_new_user'] == true,
      ),
    );
  }

  /// Signs in with a Google ID token the app obtained from Google.
  ///
  /// The token is proof, not a claim: the server checks it against Google
  /// own keys and the audience it was minted for, so a token meant for
  /// another application is refused.
  Future<SignInResult> signInWithGoogle({
    required String idToken,
    required String deviceId,
    String? displayName,
  }) {
    return _client.post(
      '/auth/google',
      body: {
        'id_token': idToken,
        'device_id': deviceId,
        if (displayName != null && displayName.trim().isNotEmpty)
          'display_name': displayName.trim(),
      },
      decode: (json) => SignInResult(
        tokens: _readTokens(json),
        isNewUser: json['is_new_user'] == true,
      ),
    );
  }

  /// Asks for a password reset code to be emailed to [email].
  ///
  /// Succeeds whether or not the address has an account: the server answers
  /// identically either way, so nobody can use this to find out who has one.
  ///
  /// Returns the code itself when the server has no way to send email, which
  /// only a development or staging deployment can answer. In production it is
  /// always null, and the code is in the user's inbox.
  Future<String?> requestPasswordReset({required String email}) {
    return _client.post(
      '/auth/forgot-password',
      body: {'email': email},
      decode: (json) => switch (json['reset_code']) {
        final String code when code.isNotEmpty => code,
        _ => null,
      },
    );
  }

  /// Sets a new password using the [code] emailed to [email].
  ///
  /// The server ends every session the account had, so signing in afterwards
  /// starts a new one.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
  }) {
    return _client.post(
      '/auth/reset-password',
      body: {'email': email, 'code': code, 'password': password},
      decode: ApiClient.ignoreData,
    );
  }

  /// Exchanges [refreshToken] for a new pair. The server retires
  /// [refreshToken], so it must never be sent again.
  Future<AuthTokens> refresh(String refreshToken) {
    return _client.post(
      '/auth/refresh',
      body: {'refresh_token': refreshToken},
      decode: _readTokens,
    );
  }

  /// Revokes the session that [refreshToken] belongs to on the server.
  Future<void> logout(String refreshToken) {
    return _client.post(
      '/auth/logout',
      body: {'refresh_token': refreshToken},
      decode: ApiClient.ignoreData,
    );
  }

  AuthTokens _readTokens(JsonMap json) {
    return AuthTokens.fromResponse(json, receivedAt: _clock());
  }
}

/// What came of signing in a way that can also create the account.
@immutable
final class SignInResult {
  const SignInResult({required this.tokens, required this.isNewUser});

  final AuthTokens tokens;

  /// True when there was no account until now. A new account made this way
  /// has no date of birth, which is what onboarding asks for first — neither
  /// a phone number nor Google carries one.
  final bool isNewUser;
}
