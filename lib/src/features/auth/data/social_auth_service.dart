import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_api.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/google_identity.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/device/client_info.dart';
import '../../../core/device/device_providers.dart';

/// Signing in with Google.
///
/// Two steps that must not be confused: Google proves who the person is, and
/// our server decides what that means for Kinvo. The app only carries the
/// proof between them — it never reads an identity out of the token itself,
/// because a token this app has not verified is just a string it was handed.
///
/// A Google account nobody has used here before gets a Kinvo account, which is
/// why this is both signing in and signing up. That account has no date of
/// birth, so the router sends it to onboarding, where the first question is
/// exactly that.
final class SocialAuthService {
  SocialAuthService({
    required AuthApi api,
    required SessionManager session,
    required GoogleIdentity google,
    required Future<ClientInfo> Function() clientInfo,
  }) : _api = api,
       _session = session,
       _google = google,
       _clientInfo = clientInfo;

  final AuthApi _api;
  final SessionManager _session;
  final GoogleIdentity _google;
  final Future<ClientInfo> Function() _clientInfo;

  /// Whether this build can offer Google at all.
  bool get canUseGoogle => _google.isAvailable;

  /// Signs in with Google.
  ///
  /// Returns whether the account was created just now, or null when the
  /// person backed out of Google's own screen — which is not a failure and
  /// must not be reported as one.
  ///
  /// Throws [GoogleSignInRefused] when Google could not finish, and
  /// `ApiException` when our server refused what Google gave.
  Future<bool?> signInWithGoogle() async {
    final account = await _google.signIn();
    if (account == null) return null;

    final client = await _clientInfo();

    final result = await _api.signInWithGoogle(
      idToken: account.idToken,
      deviceId: client.deviceId,
      // Google stops sending the name once an account exists, so it is worth
      // passing whenever it is there; the server ignores it for an account it
      // already has.
      displayName: account.displayName,
    );

    await _session.signIn(result.tokens);
    return result.isNewUser;
  }

  /// Forgets the Google account on this device, so the next sign-in asks
  /// which account to use instead of silently picking the last one.
  Future<void> forgetGoogle() => _google.signOut();
}

final socialAuthServiceProvider = Provider<SocialAuthService>((ref) {
  return SocialAuthService(
    api: ref.watch(authApiProvider),
    session: ref.watch(sessionManagerProvider),
    google: ref.watch(googleIdentityProvider),
    clientInfo: () => ref.read(clientInfoProvider.future),
  );
});
