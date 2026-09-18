import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/account.dart';
import '../auth/session_status.dart';
import 'app_routes.dart';

/// Where the router sends someone heading for [target], or `null` to let them
/// through.
///
/// - While the saved session is read, everything waits on the splash screen,
///   which remembers [target].
/// - A suspended account only reaches the suspension screen.
/// - Signed out, only the welcome and sign-in screens are open, unless the
///   user is exploring the demo.
/// - Signed in, the account decides: it waits on the splash while loading,
///   goes to onboarding until profile setup is finished, and is kept out of
///   the signed-out screens afterwards.
String? redirectFor({
  required Uri target,
  required SessionStatus session,
  required AsyncValue<Account?> account,
  required bool inDemo,
}) {
  final path = target.path;

  switch (session) {
    case SessionRestoring():
      return path == AppRoutes.splash ? null : AppRoutes.splashThen(target);

    case AccountSuspended():
      return path == AppRoutes.suspended ? null : AppRoutes.suspended;

    case SignedOut() when inDemo:
      // The demo has no account to set up.
      return _systemRoutes.contains(path) || path == AppRoutes.onboarding
          ? AppRoutes.discover
          : null;

    case SignedOut():
      return _signedOutRoutes.contains(path) ? null : AppRoutes.welcome;

    case SignedIn():
      final current = account.value;
      if (current == null) {
        // Loading, or failed with nothing to show: the splash screen offers a
        // retry.
        return path == AppRoutes.splash ? null : AppRoutes.splashThen(target);
      }
      if (!current.isOnboarded) {
        return path == AppRoutes.onboarding ? null : AppRoutes.onboarding;
      }
      if (_systemRoutes.contains(path) ||
          _signedOutRoutes.contains(path) ||
          path == AppRoutes.onboarding) {
        return _rememberedDestination(target) ?? AppRoutes.discover;
      }
      return null;
  }
}

const _systemRoutes = {AppRoutes.splash, AppRoutes.suspended};

const _signedOutRoutes = {
  AppRoutes.welcome,
  AppRoutes.signup,
  AppRoutes.otp,
  AppRoutes.login,
  AppRoutes.resetPassword,
  AppRoutes.newPassword,
};

/// The in-app location the splash screen was asked to continue to, if it's
/// safe to go there.
String? _rememberedDestination(Uri target) {
  if (target.path != AppRoutes.splash) return null;

  final raw = target.queryParameters[AppRoutes.splashDestinationParameter];
  // Only paths inside the app: a scheme or a leading "//" would leave it.
  if (raw == null || !raw.startsWith('/') || raw.startsWith('//')) return null;

  final destination = Uri.tryParse(raw);
  if (destination == null ||
      destination.hasScheme ||
      _systemRoutes.contains(destination.path) ||
      _signedOutRoutes.contains(destination.path) ||
      destination.path == AppRoutes.onboarding) {
    return null;
  }
  return raw;
}
