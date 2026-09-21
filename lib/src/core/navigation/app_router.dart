import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/new_password_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/password_reset_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/calls/presentation/screens/call_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/connections/domain/connection.dart';
import '../../features/connections/presentation/controllers/connections_controller.dart';
import '../../features/discovery/presentation/screens/discover_screen.dart';
import '../../features/home/presentation/screens/home_shell.dart';
import '../../features/matches/presentation/screens/matches_screen.dart';
import '../../features/more/presentation/screens/more_screen.dart';
import '../../features/more/presentation/screens/premium_screen.dart';
import '../../features/more/presentation/screens/report_screen.dart';
import '../../features/more/presentation/screens/safety_center_screen.dart';
import '../../features/more/presentation/screens/settings_screen.dart';
import '../../features/more/presentation/screens/support_screen.dart';
import '../../features/more/presentation/screens/theme_screen.dart';
import '../../features/more/presentation/screens/trusted_contacts_screen.dart';
import '../../features/notifications/presentation/screens/notification_settings_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/plans/presentation/screens/plan_composer_screen.dart';
import '../../features/plans/presentation/screens/plan_detail_screen.dart';
import '../../features/plans/presentation/screens/plans_screen.dart';
import '../../features/plans/presentation/screens/venues_screen.dart';
import '../../features/profile/presentation/screens/interests_edit_screen.dart';
import '../../features/profile/presentation/screens/profile_edit_screen.dart';
import '../../features/profile/presentation/screens/profile_preview_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/safety/presentation/controllers/report_controller.dart';
import '../../features/settings/presentation/screens/devices_screen.dart';
import '../../features/settings/presentation/screens/privacy_screen.dart';
import '../../features/system/presentation/account_suspended_screen.dart';
import '../../features/system/presentation/not_found_screen.dart';
import '../../features/system/presentation/splash_screen.dart';
import '../../features/verification/presentation/verification_capture_screen.dart';
import '../../features/verification/presentation/verification_methods_screen.dart';
import '../../features/verification/presentation/verification_success_screen.dart';
import '../../features/welcome/presentation/welcome_screen.dart';
import '../../features/auth/presentation/controllers/password_reset_controller.dart';
import '../auth/account_providers.dart';
import '../auth/auth_providers.dart';
import '../demo/demo_mode.dart';
import 'app_routes.dart';
import 'route_guard.dart';

/// The app's router.
///
/// Created once per [ProviderScope]. Rebuilding it would reset navigation, so
/// session changes reach it through `refreshListenable` instead.
final appRouterProvider = Provider<GoRouter>((ref) {
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  final refresh = _RouterRefresh();

  // Listening also keeps the account loading whenever a session exists.
  ref
    ..listen(sessionStatusProvider, (_, _) => refresh.notify())
    ..listen(currentAccountProvider, (_, _) => refresh.notify())
    ..listen(demoSessionProvider, (_, _) => refresh.notify());

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(
      target: state.uri,
      session: ref.read(sessionStatusProvider),
      account: ref.read(currentAccountProvider),
      inDemo: ref.read(demoSessionProvider),
    ),
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: _routes(rootNavigatorKey, ref),
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

List<RouteBase> _routes(GlobalKey<NavigatorState> rootKey, Ref ref) {
  return [
    GoRoute(path: '/', redirect: (_, _) => AppRoutes.discover),
    GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
    GoRoute(
      path: AppRoutes.suspended,
      builder: (_, _) => const AccountSuspendedScreen(),
    ),
    GoRoute(path: AppRoutes.welcome, builder: (_, _) => const WelcomeScreen()),
    GoRoute(
      path: AppRoutes.signup,
      builder: (_, _) => const SignupScreen(),
      routes: [
        GoRoute(path: 'verify-code', builder: (_, _) => const OtpScreen()),
      ],
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (_, _) => const LoginScreen(),
      routes: [
        GoRoute(
          path: 'reset-password',
          builder: (_, _) => const PasswordResetScreen(),
          routes: [
            GoRoute(
              path: 'new-password',
              // Nothing to redeem without a code on its way: back to the step
              // that sends one, rather than a form that cannot work.
              redirect: (_, _) => ref.read(pendingPasswordResetProvider) == null
                  ? AppRoutes.resetPassword
                  : null,
              builder: (_, _) => const NewPasswordScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (_, _) => const OnboardingScreen(),
    ),
    // A call covers everything, from either side: the person who started it
    // and the person whose phone is ringing land on the same screen. It opens
    // itself when a call begins — see `callScreenKeeperProvider` — so nothing
    // navigates here by hand.
    GoRoute(path: AppRoutes.call, builder: (_, _) => const CallScreen()),
    GoRoute(
      path: AppRoutes.reportPath,
      builder: (_, state) {
        if (state.extra case final ReportTarget target) {
          return ReportScreen(target: target);
        }
        // The demo's video call reports someone by their sample id.
        final connectionId =
            state.uri.queryParameters[AppRoutes.reportConnectionParameter];
        return connectionId == null
            ? const ReportScreen()
            : _ConnectionPage(
                connectionId: connectionId,
                builder: (connection) => ReportScreen(
                  target: ReportTarget(
                    userId: connection.id,
                    displayName: connection.name,
                  ),
                ),
              );
      },
    ),
    StatefulShellRoute.indexedStack(
      builder: (_, _, navigationShell) =>
          HomeShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.discover,
              builder: (_, _) => const DiscoverScreen(),
              routes: [
                GoRoute(
                  path: 'notifications',
                  parentNavigatorKey: rootKey,
                  builder: (_, _) => const NotificationsScreen(),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.matches,
              builder: (_, _) => const MatchesScreen(),
              routes: [
                GoRoute(
                  path: 'chat/:conversationId',
                  parentNavigatorKey: rootKey,
                  builder: (_, state) => ChatScreen(
                    conversationId: _pathParameter(state, 'conversationId'),
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.plans,
              builder: (_, _) => const PlansScreen(),
              routes: [
                // Before ':planId', which would otherwise match them.
                GoRoute(
                  path: 'new',
                  parentNavigatorKey: rootKey,
                  builder: (_, state) => PlanComposerScreen(
                    matchId: state.uri.queryParameters['match'],
                  ),
                ),
                GoRoute(
                  path: 'places',
                  parentNavigatorKey: rootKey,
                  builder: (_, _) => const VenuesScreen(),
                ),
                GoRoute(
                  path: ':planId',
                  parentNavigatorKey: rootKey,
                  builder: (_, state) =>
                      PlanDetailScreen(planId: _pathParameter(state, 'planId')),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      parentNavigatorKey: rootKey,
                      builder: (_, state) => PlanComposerScreen(
                        planId: _pathParameter(state, 'planId'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (_, _) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'edit',
                  parentNavigatorKey: rootKey,
                  builder: (_, _) => const ProfileEditScreen(),
                  routes: [
                    GoRoute(
                      path: 'interests',
                      parentNavigatorKey: rootKey,
                      builder: (_, _) => const InterestsEditScreen(),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'preview',
                  parentNavigatorKey: rootKey,
                  builder: (_, _) => const ProfilePreviewScreen(),
                ),
                GoRoute(
                  path: 'verification',
                  parentNavigatorKey: rootKey,
                  builder: (_, _) => const VerificationMethodsScreen(),
                  routes: [
                    GoRoute(
                      path: 'capture',
                      parentNavigatorKey: rootKey,
                      builder: (_, _) => const VerificationCaptureScreen(),
                    ),
                    GoRoute(
                      path: 'submitted',
                      parentNavigatorKey: rootKey,
                      builder: (_, _) => const VerificationSuccessScreen(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.more,
              builder: (_, _) => const MoreScreen(),
              routes: [
                GoRoute(
                  path: 'premium',
                  parentNavigatorKey: rootKey,
                  builder: (_, _) => const PremiumScreen(),
                ),
                GoRoute(
                  path: 'safety',
                  parentNavigatorKey: rootKey,
                  builder: (_, _) => const SafetyCenterScreen(),
                  routes: [
                    GoRoute(
                      path: 'contacts',
                      parentNavigatorKey: rootKey,
                      builder: (_, _) => const TrustedContactsScreen(),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'privacy',
                  parentNavigatorKey: rootKey,
                  builder: (_, _) => const PrivacyScreen(),
                  routes: [
                    GoRoute(
                      path: 'devices',
                      parentNavigatorKey: rootKey,
                      builder: (_, _) => const DevicesScreen(),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'support',
                  parentNavigatorKey: rootKey,
                  builder: (_, _) => const SupportScreen(),
                ),
                GoRoute(
                  path: 'theme',
                  parentNavigatorKey: rootKey,
                  builder: (_, _) => const ThemeScreen(),
                ),
                GoRoute(
                  path: 'settings',
                  parentNavigatorKey: rootKey,
                  builder: (_, _) => const SettingsScreen(),
                  routes: [
                    GoRoute(
                      path: 'notifications',
                      parentNavigatorKey: rootKey,
                      builder: (_, _) => const NotificationSettingsScreen(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ];
}

/// The route guarantees the parameter; an empty id simply finds nothing.
String _pathParameter(GoRouterState state, String name) {
  return state.pathParameters[name] ?? '';
}

/// Builds a page for the connection named in the URL, or the not-found screen
/// when there's no such connection.
class _ConnectionPage extends ConsumerWidget {
  const _ConnectionPage({required this.connectionId, required this.builder});

  final String connectionId;
  final Widget Function(Connection connection) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionByIdProvider(connectionId));
    return connection == null ? const NotFoundScreen() : builder(connection);
  }
}

class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}
