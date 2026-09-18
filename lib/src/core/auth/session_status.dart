import 'package:flutter/foundation.dart';

/// Where the user's session stands. Drives navigation between sign-in, the
/// app, and the suspension screen.
@immutable
sealed class SessionStatus {
  const SessionStatus();
}

/// Saved tokens are still being read at startup.
final class SessionRestoring extends SessionStatus {
  const SessionRestoring();

  @override
  bool operator ==(Object other) => other is SessionRestoring;

  @override
  int get hashCode => (SessionRestoring).hashCode;

  @override
  String toString() => 'SessionRestoring()';
}

/// The user has a session. The server may still reject it later.
final class SignedIn extends SessionStatus {
  const SignedIn();

  @override
  bool operator ==(Object other) => other is SignedIn;

  @override
  int get hashCode => (SignedIn).hashCode;

  @override
  String toString() => 'SignedIn()';
}

/// Why there's no session.
enum SignOutReason {
  /// There was never a session on this device, or the user signed out.
  signedOut,

  /// The server ended the session: it expired, it was revoked from another
  /// device, or the account was deleted.
  sessionEnded,
}

/// The user must sign in.
final class SignedOut extends SessionStatus {
  const SignedOut(this.reason);

  final SignOutReason reason;

  @override
  bool operator ==(Object other) =>
      other is SignedOut && other.reason == reason;

  @override
  int get hashCode => Object.hash(SignedOut, reason);

  @override
  String toString() => 'SignedOut(${reason.name})';
}

/// The server suspended the account. Every request will be refused.
final class AccountSuspended extends SessionStatus {
  const AccountSuspended(this.message);

  /// The server's explanation, which can be shown to the user as-is.
  final String message;

  @override
  bool operator ==(Object other) =>
      other is AccountSuspended && other.message == message;

  @override
  int get hashCode => Object.hash(AccountSuspended, message);

  @override
  String toString() => 'AccountSuspended()';
}
