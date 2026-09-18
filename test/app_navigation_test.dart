import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/auth/account_providers.dart';
import 'package:kinvo/src/core/demo/demo_mode.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';
import 'package:kinvo/src/features/home/presentation/widgets/home_bottom_nav.dart';
import 'package:kinvo/src/features/matches/presentation/screens/matches_screen.dart';
import 'package:kinvo/src/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:kinvo/src/features/plans/presentation/screens/plans_screen.dart';
import 'package:kinvo/src/features/system/presentation/not_found_screen.dart';
import 'package:kinvo/src/features/system/presentation/splash_screen.dart';

import 'helpers/app_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fake_kinvo_server.dart';

/// A backend where `/auth/me` answers with [account] and every other request
/// succeeds with an empty object.
FakeResponder backendWithAccount(Map<String, Object?> account) {
  return (options) async {
    if (options.uri.path.endsWith('/auth/me')) {
      return jsonResponse(200, successEnvelope(account));
    }
    return jsonResponse(200, successEnvelope(<String, Object?>{}));
  };
}

const onboardedAccount = {
  'id': 'u1',
  'display_name': 'Sarah',
  'is_onboarded': true,
};

void main() {
  testWidgets('signed out, the app opens on the welcome screen', (
    tester,
  ) async {
    final app = await pumpKinvoApp(tester);

    await app.pumpUntilFound(find.text('Create Account'));
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Explore Demo'), findsOneWidget);
  });

  testWidgets('signed in with a finished profile, the app opens on Discover', (
    tester,
  ) async {
    final app = await pumpKinvoApp(
      tester,
      savedSession: liveSession(),
      respond: backendWithAccount(onboardedAccount),
    );

    await app.pumpUntilFound(find.byType(DiscoverScreen));
    await app.pumpUntilLoaded();

    await tester.tap(
      find.descendant(
        of: find.byType(HomeBottomNav),
        matching: find.text('Plans'),
      ),
    );
    await app.pumpUntilFound(find.byType(PlansScreen));
    await app.pumpUntilLoaded();
  });

  testWidgets(
    'signed in without a finished profile, the app opens onboarding',
    (tester) async {
      final app = await pumpKinvoApp(
        tester,
        savedSession: liveSession(),
        respond: FakeKinvoServer().respond,
      );

      await app.pumpUntilFound(find.byType(OnboardingScreen));
      await app.pumpUntilFound(find.text('About you'));
    },
  );

  testWidgets('refreshing the account keeps the current screen', (
    tester,
  ) async {
    var accountRequests = 0;
    final app = await pumpKinvoApp(
      tester,
      savedSession: liveSession(),
      respond: (options) async {
        if (options.uri.path.endsWith('/auth/me')) {
          if (++accountRequests > 1) {
            await Future<void>.delayed(const Duration(seconds: 2));
          }
          return jsonResponse(200, successEnvelope(onboardedAccount));
        }
        return jsonResponse(200, successEnvelope(<String, Object?>{}));
      },
    );
    await app.pumpUntilFound(find.byType(DiscoverScreen));
    await app.pumpUntilLoaded();

    app.container.invalidate(currentAccountProvider);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(DiscoverScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a suspended account sees why and can sign out', (tester) async {
    final app = await pumpKinvoApp(
      tester,
      savedSession: liveSession(),
      respond: (options) async {
        if (options.uri.path.endsWith('/auth/me')) {
          return jsonResponse(
            403,
            errorEnvelope('ACCOUNT_SUSPENDED', 'Suspended for spamming.'),
          );
        }
        return jsonResponse(200, successEnvelope({'signed_out': true}));
      },
    );

    await app.pumpUntilFound(find.text('Suspended for spamming.'));

    await tester.tap(find.text('Sign out'));
    await app.pumpUntilFound(find.text('Create Account'));
    expect(
      app.adapter.requests.map((r) => r.uri.path),
      contains('/api/v1/auth/logout'),
    );
  });

  testWidgets(
    'when the account cannot load, the splash screen offers a retry',
    (tester) async {
      var online = false;
      final app = await pumpKinvoApp(
        tester,
        savedSession: liveSession(),
        respond: (options) async {
          if (!online) throw const SocketException('Network is unreachable');
          return backendWithAccount(onboardedAccount)(options);
        },
      );

      await app.pumpUntilFound(find.text('Try again'));
      expect(
        find.textContaining('Check your internet connection'),
        findsOneWidget,
      );

      online = true;
      await tester.tap(find.text('Try again'));
      await app.pumpUntilFound(find.byType(DiscoverScreen));
      await app.pumpUntilLoaded();
    },
  );

  testWidgets('Explore Demo opens the app on sample data', (tester) async {
    final app = await pumpKinvoApp(tester);
    await app.pumpUntilFound(find.text('Explore Demo'));

    await tester.tap(find.text('Explore Demo'));

    await app.pumpUntilFound(find.byType(DiscoverScreen));
    await app.pumpUntilLoaded();
    expect(app.adapter.requests, isEmpty);
  });

  testWidgets('builds without demo mode hide Explore Demo', (tester) async {
    final app = await pumpKinvoApp(tester, demoAvailable: false);

    await app.pumpUntilFound(find.text('Create Account'));
    expect(find.text('Explore Demo'), findsNothing);
  });

  testWidgets('every app location opens its screen', (tester) async {
    final app = await pumpKinvoApp(tester);
    await app.pumpUntilFound(find.text('Create Account'));
    app.container.read(demoSessionProvider.notifier).start();

    final locations = [
      AppRoutes.discover,
      AppRoutes.notifications,
      AppRoutes.matches,
      AppRoutes.chat('sarah'),
      AppRoutes.videoCall('sarah'),
      AppRoutes.plans,
      AppRoutes.planComposer,
      AppRoutes.planWith('sarah'),
      AppRoutes.venues,
      AppRoutes.plan('demo-plan-1'),
      AppRoutes.editPlan('demo-plan-4'),
      AppRoutes.profile,
      AppRoutes.profileEdit,
      AppRoutes.profileInterests,
      AppRoutes.profileReview,
      AppRoutes.verificationMethods,
      AppRoutes.verificationCapture,
      AppRoutes.verificationSuccess,
      AppRoutes.more,
      AppRoutes.premium,
      AppRoutes.safetyCenter,
      AppRoutes.trustedContacts,
      AppRoutes.privacy,
      AppRoutes.devices,
      AppRoutes.support,
      AppRoutes.theme,
      AppRoutes.settings,
      AppRoutes.notificationSettings,
      AppRoutes.report(),
      AppRoutes.report(connectionId: 'sarah'),
    ];

    for (final location in locations) {
      app.router.go(location);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(NotFoundScreen), findsNothing, reason: location);
      expect(
        app.router.routeInformationProvider.value.uri.toString(),
        location,
        reason: 'redirected away from $location',
      );
    }

    // Leave screens with timers, such as the video call.
    app.router.go(AppRoutes.discover);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('a link to a missing conversation says it is not available', (
    tester,
  ) async {
    final app = await pumpKinvoApp(tester);
    await app.pumpUntilFound(find.text('Create Account'));
    app.container.read(demoSessionProvider.notifier).start();

    app.router.go(AppRoutes.chat('nobody'));
    await app.pumpUntilFound(find.text("This conversation isn't available"));

    await tester.tap(find.text('Back to matches'));
    await app.pumpUntilFound(find.byType(MatchesScreen));
    await app.pumpUntilLoaded();
  });
}
