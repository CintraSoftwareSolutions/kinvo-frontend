import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Someone who has just proved to Google who they are.
///
/// The token is all that matters here: the server verifies it against Google's
/// own keys before it believes a single field, so nothing this app reads out
/// of it would be trusted anyway.
@immutable
final class GoogleAccount {
  const GoogleAccount({required this.idToken, this.displayName});

  /// The signed proof, checked by the server.
  final String idToken;

  /// Their name at Google, used only when the account is brand new. Google
  /// stops sending it once an account exists, exactly as Apple does.
  final String? displayName;
}

/// Why signing in with Google could not be finished.
enum GoogleSignInFailure {
  /// This build has no Google settings, or the phone has no Google services.
  unavailable('Google sign-in is not available on this phone.'),

  /// Google refused the app itself: a missing fingerprint, the wrong client
  /// id, or a package name that does not match what is registered.
  misconfigured(
    "Google sign-in isn't set up for this build yet. Use your email address "
    'for now.',
  ),

  /// Google was reachable but the sign-in did not finish.
  failed('Could not finish signing in with Google. Please try again.');

  const GoogleSignInFailure(this.message);

  /// Text that can be shown to the user as-is.
  final String message;
}

final class GoogleSignInRefused implements Exception {
  const GoogleSignInRefused(this.failure);

  final GoogleSignInFailure failure;

  @override
  String toString() => 'GoogleSignInRefused(${failure.name})';
}

/// Signing in with Google, behind an interface so tests never talk to Google
/// and the vendor package is imported in one file.
abstract interface class GoogleIdentity {
  /// Whether this build can offer Google at all. The button is hidden when
  /// it cannot, rather than failing when pressed.
  bool get isAvailable;

  /// Signs in, or returns null when the person backed out.
  ///
  /// Throws [GoogleSignInRefused] for anything else.
  Future<GoogleAccount?> signIn();

  /// Forgets the account on this device, so the next sign-in asks again.
  Future<void> signOut();
}

/// The real thing, on `google_sign_in`.
final class DeviceGoogleIdentity implements GoogleIdentity {
  DeviceGoogleIdentity({required this.serverClientId, GoogleSignIn? google})
    : _google = google ?? GoogleSignIn.instance;

  /// The web client id from the Google project. It is the audience the server
  /// checks the token against, so the two must name the same client or every
  /// sign-in is refused — correctly.
  ///
  /// Not a secret: it identifies the application, and ships inside it.
  final String serverClientId;

  final GoogleSignIn _google;

  Future<void>? _started;

  @override
  bool get isAvailable => _google.supportsAuthenticate();

  @override
  Future<GoogleAccount?> signIn() async {
    if (!isAvailable) {
      throw const GoogleSignInRefused(GoogleSignInFailure.unavailable);
    }

    try {
      // Once per run, and kept so a second press does not start it again.
      _started ??= _google.initialize(serverClientId: serverClientId);
      await _started;

      final account = await _google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        // Google signed somebody in but gave us nothing to prove it with,
        // which happens when the server client id is missing or wrong.
        throw const GoogleSignInRefused(GoogleSignInFailure.misconfigured);
      }

      return GoogleAccount(
        idToken: idToken,
        displayName: account.displayName?.trim(),
      );
    } on GoogleSignInException catch (error, stackTrace) {
      _started = null;
      if (error.code == GoogleSignInExceptionCode.canceled) return null;

      _log('Google sign-in failed.', error, stackTrace);
      throw GoogleSignInRefused(switch (error.code) {
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          GoogleSignInFailure.misconfigured,
        GoogleSignInExceptionCode.uiUnavailable =>
          GoogleSignInFailure.unavailable,
        _ => GoogleSignInFailure.failed,
      });
    }
  }

  @override
  Future<void> signOut() async {
    if (_started == null) return;
    try {
      await _google.signOut();
    } on GoogleSignInException catch (error, stackTrace) {
      // Signing out of Google is a courtesy; the Kinvo session has already
      // ended and failing here must not stop that.
      _log('Could not sign out of Google.', error, stackTrace);
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

/// What a build with no Google settings gets: an honest "no".
final class UnavailableGoogleIdentity implements GoogleIdentity {
  const UnavailableGoogleIdentity();

  @override
  bool get isAvailable => false;

  @override
  Future<GoogleAccount?> signIn() {
    throw const GoogleSignInRefused(GoogleSignInFailure.unavailable);
  }

  @override
  Future<void> signOut() async {}
}

/// The web client id this build was given, or null when it was given none.
///
/// Supplied with the other build settings, for example in `env/staging.json`.
String? googleServerClientIdFromEnvironment() {
  const value = String.fromEnvironment(googleServerClientIdKey);
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

const googleServerClientIdKey = 'GOOGLE_SERVER_CLIENT_ID';

final googleIdentityProvider = Provider<GoogleIdentity>((ref) {
  final serverClientId = googleServerClientIdFromEnvironment();
  if (serverClientId == null) return const UnavailableGoogleIdentity();

  return DeviceGoogleIdentity(serverClientId: serverClientId);
});
