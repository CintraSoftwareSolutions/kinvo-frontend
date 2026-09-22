/// Every location in the app.
///
/// Build paths with these constants and helpers rather than by hand, so a
/// link can't drift from the route it points at.
abstract final class AppRoutes {
  // System
  static const splash = '/splash';
  static const suspended = '/account-suspended';

  // Signed out
  static const welcome = '/welcome';
  static const signup = '/signup';
  static const otp = '/signup/verify-code';
  static const login = '/login';
  static const resetPassword = '/login/reset-password';
  static const newPassword = '/login/reset-password/new-password';

  // Signed in, before the app
  static const onboarding = '/onboarding';

  // Tabs, in bottom-navigation order
  static const discover = '/discover';
  static const matches = '/matches';
  static const plans = '/plans';
  static const profile = '/profile';
  static const more = '/more';

  // Discover
  static const notifications = '/discover/notifications';

  // Matches
  static String chat(String conversationId) {
    return '$matches/chat/${Uri.encodeComponent(conversationId)}';
  }

  /// Every call so far, in More.
  static const calls = '/more/calls';

  /// The call in progress. It takes no id: only one call happens at a time,
  /// and the screen reads it from the call controller, so a link left in
  /// history can never reopen a call that has ended.
  static const call = '/call';

  // Plans
  static const planComposer = '/plans/new';

  /// A new plan with the match [matchId] already chosen, as a chat opens it.
  static String planWith(String matchId) {
    return '$planComposer?match=${Uri.encodeQueryComponent(matchId)}';
  }

  /// Places to meet, to choose one for a plan. Returns the one chosen.
  static const venues = '/plans/places';

  static String plan(String planId) {
    return '$plans/${Uri.encodeComponent(planId)}';
  }

  static String editPlan(String planId) => '${plan(planId)}/edit';

  // Profile
  static const profileEdit = '/profile/edit';
  static const profileInterests = '/profile/edit/interests';
  static const profileReview = '/profile/preview';
  static const verificationMethods = '/profile/verification';
  static const verificationCapture = '/profile/verification/capture';
  static const verificationSuccess = '/profile/verification/submitted';

  // More
  static const premium = '/more/premium';
  static const safetyCenter = '/more/safety';
  static const trustedContacts = '/more/safety/contacts';
  static const privacy = '/more/privacy';
  static const devices = '/more/privacy/devices';
  static const support = '/more/support';
  static const theme = '/more/theme';
  static const settings = '/more/settings';
  static const notificationSettings = '/more/settings/notifications';

  // Reachable from several tabs

  /// The report form. Push it with a `ReportTarget` as `extra` to say who
  /// the report is about.
  static const reportPath = '/report';
  static const reportConnectionParameter = 'connection';

  /// The report form, about the demo's sample person [connectionId] when
  /// given.
  static String report({String? connectionId}) {
    return Uri(
      path: reportPath,
      queryParameters: connectionId == null
          ? null
          : {reportConnectionParameter: connectionId},
    ).toString();
  }

  static const splashDestinationParameter = 'from';

  /// The splash screen, remembering [destination] so the app can continue
  /// there once the session is ready.
  static String splashThen(Uri destination) {
    return Uri(
      path: splash,
      queryParameters: {splashDestinationParameter: destination.toString()},
    ).toString();
  }
}
