import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../network/api_error_code.dart';
import '../network/api_exception.dart';
import 'auth_api.dart';
import 'auth_tokens.dart';
import 'session_status.dart';
import 'token_store.dart';

/// Owns the session: the current tokens, their saved copy, and refreshing
/// them.
///
/// Every token change goes through here, so the in-memory tokens, the saved
/// tokens and [status] can't drift apart.
final class SessionManager {
  SessionManager({
    required TokenStore store,
    required AuthApi api,
    DateTime Function()? clock,
  }) : _store = store,
       _api = api,
       _clock = clock ?? DateTime.now {
    _ready = _restore();
  }

  /// Access tokens are refreshed this long before they expire, so a request
  /// doesn't leave with a token that lapses while it's in flight.
  static const refreshMargin = Duration(minutes: 1);

  /// Longest sign-out waits for the server to revoke the session.
  static const revokeTimeout = Duration(seconds: 5);

  final TokenStore _store;
  final AuthApi _api;
  final DateTime Function() _clock;

  final ValueNotifier<SessionStatus> _status = ValueNotifier(
    const SessionRestoring(),
  );

  late final Future<void> _ready;
  AuthTokens? _tokens;
  Future<AuthTokens?>? _refreshInFlight;

  /// Whether the session is saved, so it survives the app closing.
  bool _remember = true;

  /// Changes whenever the session is started, replaced or ended, so work that
  /// began under an older session can tell its result no longer applies.
  int _generation = 0;

  /// The session's current status. Listenable, for routing.
  ValueListenable<SessionStatus> get status => _status;

  /// Completes once saved tokens have been read at startup.
  Future<void> get ready => _ready;

  /// Starts a session with tokens from a sign-in endpoint.
  ///
  /// When [remember] is false the session is kept in memory only, so it ends
  /// when the app closes. The server still holds it until the refresh token
  /// expires.
  Future<void> signIn(AuthTokens tokens, {bool remember = true}) async {
    await _ready;
    _generation++;
    _tokens = tokens;
    _remember = remember;
    _status.value = const SignedIn();
    if (remember) {
      await _save(tokens);
    } else {
      // Saved tokens from an earlier session must not come back next launch.
      await _store.clear();
    }
  }

  /// Ends the session on this device, then asks the server to revoke it.
  ///
  /// [status] changes immediately. Revoking is best effort: if the server
  /// can't be reached, the device has still forgotten the tokens.
  Future<void> signOut() async {
    await _ready;
    final tokens = _tokens;
    await _end(SignOutReason.signedOut);
    if (tokens != null) {
      await _revokeQuietly(tokens.refreshToken);
    }
  }

  /// The access token to send with a request, or `null` when signed out.
  ///
  /// Refreshes first when the token is about to expire. If that refresh fails
  /// for a temporary reason but the token hasn't actually expired yet, the
  /// token is still used; otherwise the failure is rethrown.
  Future<String?> accessTokenForRequest() async {
    await _ready;
    final tokens = _tokens;
    if (tokens == null) return null;
    if (!tokens.expiresWithin(refreshMargin, now: _clock())) {
      return tokens.accessToken;
    }

    try {
      return (await refresh())?.accessToken;
    } on ApiException {
      if (!tokens.expiresWithin(Duration.zero, now: _clock())) {
        return tokens.accessToken;
      }
      rethrow;
    }
  }

  /// The access token to retry with after the server answered
  /// `AUTH_TOKEN_EXPIRED` for [rejectedAccessToken], or `null` when the session
  /// has ended.
  ///
  /// When another request already refreshed the session, its token is reused
  /// instead of refreshing again.
  Future<String?> accessTokenAfterExpiry(String rejectedAccessToken) async {
    await _ready;
    final tokens = _tokens;
    if (tokens == null) return null;
    if (tokens.accessToken != rejectedAccessToken) return tokens.accessToken;
    return (await refresh())?.accessToken;
  }

  /// Exchanges the refresh token for a new pair.
  ///
  /// Concurrent callers share one request: the server replaces the refresh
  /// token on every use and treats a second use of the old one as theft,
  /// revoking the session on every device.
  ///
  /// Returns `null` when there's no session or the server ended it. Temporary
  /// failures, such as being offline or rate limited, are rethrown and leave
  /// the session untouched.
  Future<AuthTokens?> refresh() {
    return _refreshInFlight ??= _refresh().whenComplete(
      () => _refreshInFlight = null,
    );
  }

  /// Ends the session because the server rejected [rejectedAccessToken] as
  /// invalid. Ignored when that token belongs to a session already replaced.
  Future<void> handleRejectedSession(String rejectedAccessToken) async {
    await _ready;
    if (_tokens?.accessToken != rejectedAccessToken) return;
    await _end(SignOutReason.sessionEnded);
  }

  /// Records that the server suspended the account. The tokens are kept so
  /// signing out can still revoke them.
  void handleAccountSuspended(String message) {
    if (_tokens != null) {
      _status.value = AccountSuspended(message);
    }
  }

  void dispose() => _status.dispose();

  Future<void> _restore() async {
    final tokens = await _store.read();
    _tokens = tokens;
    _status.value = tokens == null
        ? const SignedOut(SignOutReason.signedOut)
        : const SignedIn();
  }

  Future<AuthTokens?> _refresh() async {
    await _ready;
    final current = _tokens;
    if (current == null) return null;
    final generation = _generation;

    final AuthTokens fresh;
    try {
      fresh = await _api.refresh(current.refreshToken);
    } on ApiErrorException catch (error) {
      if (!_endsSession(error.code)) rethrow;
      if (generation == _generation) {
        await _end(SignOutReason.sessionEnded);
      }
      return null;
    }

    if (generation != _generation) {
      // Signed out or signed in again while refreshing. The new pair belongs
      // to nobody, so revoke it rather than leave a live session behind.
      unawaited(_revokeQuietly(fresh.refreshToken));
      return null;
    }

    _tokens = fresh;
    if (_remember) await _save(fresh);
    return fresh;
  }

  /// Refresh answers that mean the refresh token will never work again.
  static bool _endsSession(ApiErrorCode code) {
    return switch (code) {
      ApiErrorCode.authTokenInvalid ||
      ApiErrorCode.authTokenExpired ||
      ApiErrorCode.authRequired ||
      ApiErrorCode.validationFailed => true,
      _ => false,
    };
  }

  Future<void> _end(SignOutReason reason) async {
    _generation++;
    _tokens = null;
    _status.value = SignedOut(reason);
    await _store.clear();
  }

  Future<void> _save(AuthTokens tokens) async {
    try {
      await _store.write(tokens);
    } on Object catch (error, stackTrace) {
      _log(
        'Could not save the session; it will end when the app closes.',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _revokeQuietly(String refreshToken) async {
    try {
      await _api.logout(refreshToken).timeout(revokeTimeout);
    } on Object catch (error, stackTrace) {
      _log('Could not revoke the session on the server.', error, stackTrace);
    }
  }

  static void _log(String message, Object error, StackTrace stackTrace) {
    developer.log(
      message,
      name: 'kinvo.auth',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
