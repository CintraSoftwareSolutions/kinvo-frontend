import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_api.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/network/api_exception.dart';
import 'email_auth_service.dart';

/// How a finished reset leaves the user.
enum PasswordResetOutcome {
  /// The new password worked and a session has started.
  signedIn,

  /// The password was changed, but signing in with it didn't work — because
  /// the app is offline, or too many sign-ins have been tried. The user signs
  /// in themselves.
  signInRequired,
}

/// Resetting a forgotten password: ask for a code, then set a new password
/// with it.
///
/// The server only ever says "if that address has an account, a code is on its
/// way", so neither this class nor the screens above it can tell the user
/// whether the address is registered.
final class PasswordResetService {
  PasswordResetService({required AuthApi api, required EmailAuthService signIn})
    : _api = api,
      _signIn = signIn;

  final AuthApi _api;
  final EmailAuthService _signIn;

  /// Sends a code to [email].
  Future<void> sendCode({required String email}) {
    return _api.requestPasswordReset(email: email.trim());
  }

  /// Sets [password] as the account's password, using the code from the email.
  ///
  /// Signs in afterwards, since the server has just ended every session the
  /// account had — including this one, if the user was somehow still in it.
  /// The sign-in is the only part allowed to fail quietly: by then the
  /// password IS the new one, and saying the reset failed would send the user
  /// round the whole flow again with a code that no longer works.
  Future<PasswordResetOutcome> confirm({
    required String email,
    required String code,
    required String password,
  }) async {
    final address = email.trim();
    await _api.resetPassword(email: address, code: code, password: password);

    try {
      await _signIn.login(email: address, password: password, remember: true);
      return PasswordResetOutcome.signedIn;
    } on ApiException catch (error, stackTrace) {
      developer.log(
        'Password reset succeeded but signing in did not.',
        name: 'kinvo.auth',
        error: error,
        stackTrace: stackTrace,
      );
      return PasswordResetOutcome.signInRequired;
    }
  }
}

final passwordResetServiceProvider = Provider<PasswordResetService>((ref) {
  return PasswordResetService(
    api: ref.watch(authApiProvider),
    signIn: ref.watch(emailAuthServiceProvider),
  );
});
