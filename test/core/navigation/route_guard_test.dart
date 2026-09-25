import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/auth/account.dart';
import 'package:kinvo/src/core/auth/session_status.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/core/navigation/route_guard.dart';

const _onboarded = Account(id: 'u1', displayName: 'Sarah', isOnboarded: true);
const _needsOnboarding = Account(
  id: 'u1',
  displayName: 'Sarah',
  isOnboarded: false,
);

String? _redirect(
  String location, {
  SessionStatus session = const SignedOut(SignOutReason.signedOut),
  AsyncValue<Account?> account = const AsyncData(null),
}) {
  return redirectFor(
    target: Uri.parse(location),
    session: session,
    account: account,
  );
}

void main() {
  group('while the session is restoring', () {
    const session = SessionRestoring();

    test('waits on the splash screen, remembering the destination', () {
      final redirect = _redirect('/matches/chat/sarah', session: session);

      expect(Uri.parse(redirect!).path, AppRoutes.splash);
      expect(
        Uri.parse(redirect).queryParameters['from'],
        '/matches/chat/sarah',
      );
    });

    test('stays on the splash screen', () {
      expect(_redirect(AppRoutes.splash, session: session), isNull);
    });
  });

  group('when signed out', () {
    test('allows the welcome and sign-in screens', () {
      for (final location in [
        AppRoutes.welcome,
        AppRoutes.signup,
        AppRoutes.login,
        AppRoutes.phoneSignIn,
        AppRoutes.resetPassword,
      ]) {
        expect(_redirect(location), isNull, reason: location);
      }
    });

    test('sends everything else to the welcome screen', () {
      for (final location in [
        AppRoutes.discover,
        AppRoutes.chat('sarah'),
        AppRoutes.onboarding,
        AppRoutes.splash,
        AppRoutes.suspended,
      ]) {
        expect(_redirect(location), AppRoutes.welcome, reason: location);
      }
    });
  });

  group('when signed in', () {
    const session = SignedIn();

    test('waits on the splash screen while the account loads', () {
      final redirect = _redirect(
        AppRoutes.plans,
        session: session,
        account: const AsyncLoading(),
      );

      expect(Uri.parse(redirect!).path, AppRoutes.splash);
    });

    test('keeps a failed account load on the splash screen', () {
      final failed = AsyncError<Account?>(
        Exception('offline'),
        StackTrace.empty,
      );

      expect(
        _redirect(AppRoutes.splash, session: session, account: failed),
        isNull,
      );
    });

    test('sends an account without a finished profile to onboarding', () {
      const account = AsyncData<Account?>(_needsOnboarding);

      expect(
        _redirect(AppRoutes.discover, session: session, account: account),
        AppRoutes.onboarding,
      );
      expect(
        _redirect(AppRoutes.onboarding, session: session, account: account),
        isNull,
      );
    });

    group('with a finished profile', () {
      const account = AsyncData<Account?>(_onboarded);

      test('allows the app', () {
        expect(
          _redirect(
            AppRoutes.chat('sarah'),
            session: session,
            account: account,
          ),
          isNull,
        );
      });

      test('leaves the signed-out and setup screens for Discover', () {
        for (final location in [
          AppRoutes.welcome,
          AppRoutes.login,
          AppRoutes.onboarding,
          AppRoutes.suspended,
        ]) {
          expect(
            _redirect(location, session: session, account: account),
            AppRoutes.discover,
            reason: location,
          );
        }
      });

      test(
        'continues from the splash screen to the remembered destination',
        () {
          final splash = AppRoutes.splashThen(Uri.parse('/matches/chat/sarah'));

          expect(
            _redirect(splash, session: session, account: account),
            '/matches/chat/sarah',
          );
        },
      );

      test('ignores remembered destinations outside the app', () {
        for (final destination in [
          'https://example.com/phish',
          '//example.com',
          AppRoutes.login,
          AppRoutes.splash,
        ]) {
          final splash = Uri(
            path: AppRoutes.splash,
            queryParameters: {'from': destination},
          ).toString();

          expect(
            _redirect(splash, session: session, account: account),
            AppRoutes.discover,
            reason: destination,
          );
        }
      });
    });
  });

  test('a suspended account only reaches the suspension screen', () {
    const session = AccountSuspended('Suspended.');

    expect(
      _redirect(AppRoutes.discover, session: session),
      AppRoutes.suspended,
    );
    expect(_redirect(AppRoutes.welcome, session: session), AppRoutes.suspended);
    expect(_redirect(AppRoutes.suspended, session: session), isNull);
  });
}
