import 'package:flutter/material.dart';

import 'core/navigation/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/otp_screen.dart';
import 'features/auth/presentation/screens/password_reset_screen.dart';
import 'features/auth/presentation/screens/signup_screen.dart';
import 'features/connections/domain/connection.dart';
import 'features/connections/presentation/screens/chat_review_screen.dart';
import 'features/connections/presentation/screens/chat_screen.dart';
import 'features/connections/presentation/screens/video_call_screen.dart';
import 'features/home/presentation/screens/home_shell.dart';
import 'features/more/presentation/screens/mode_privacy_screen.dart';
import 'features/more/presentation/screens/notifications_screen.dart';
import 'features/more/presentation/screens/premium_screen.dart';
import 'features/more/presentation/screens/report_screen.dart';
import 'features/more/presentation/screens/safety_center_screen.dart';
import 'features/more/presentation/screens/settings_screen.dart';
import 'features/more/presentation/screens/support_screen.dart';
import 'features/more/presentation/screens/theme_screen.dart';
import 'features/more/presentation/screens/trusted_contacts_screen.dart';
import 'features/onboarding/presentation/screens/profile_setup_screen.dart';
import 'features/plans/presentation/screens/plan_composer_screen.dart';
import 'features/plans/presentation/screens/venues_screen.dart';
import 'features/profile/presentation/screens/profile_edit_screen.dart';
import 'features/profile/presentation/screens/profile_review_screen.dart';
import 'features/verification/presentation/verification_capture_screen.dart';
import 'features/verification/presentation/verification_methods_screen.dart';
import 'features/verification/presentation/verification_success_screen.dart';
import 'features/welcome/presentation/welcome_screen.dart';

class KinvoApp extends StatelessWidget {
  const KinvoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kinvo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: AppRoutes.welcome,
      onGenerateRoute: _onGenerateRoute,
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.welcome:
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      case AppRoutes.signup:
        return MaterialPageRoute(builder: (_) => const SignupScreen());
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case AppRoutes.otp:
        return MaterialPageRoute(builder: (_) => const OtpScreen());
      case AppRoutes.resetPassword:
        return MaterialPageRoute(builder: (_) => const PasswordResetScreen());
      case AppRoutes.onboarding:
        return MaterialPageRoute(builder: (_) => const ProfileSetupScreen());
      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const HomeShell());

      case AppRoutes.chat:
        final connection = settings.arguments as Connection;
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: const Color(0xFFF8F9FE),
            body: SafeArea(child: ChatScreen(connection: connection)),
          ),
        );
      case AppRoutes.chatReview:
        final draft = settings.arguments as String;
        return PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, _, _) => ChatReviewScreen(draftText: draft),
        );
      case AppRoutes.videoCall:
        final connection = settings.arguments as Connection;
        return MaterialPageRoute(
          builder: (_) => VideoCallScreen(connection: connection),
        );

      case AppRoutes.planComposer:
        return PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, _, _) => const PlanComposerScreen(),
        );
      case AppRoutes.venues:
        return MaterialPageRoute(builder: (_) => const VenuesScreen());

      case AppRoutes.profileEdit:
        return MaterialPageRoute(builder: (_) => const ProfileEditScreen());
      case AppRoutes.profileReview:
        return PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, _, _) => const ProfileReviewScreen(),
        );
      case AppRoutes.verificationMethods:
        return MaterialPageRoute(
          builder: (_) => const VerificationMethodsScreen(),
        );
      case AppRoutes.verificationCapture:
        return MaterialPageRoute(
          builder: (_) => const VerificationCaptureScreen(),
        );
      case AppRoutes.verificationSuccess:
        return MaterialPageRoute(
          builder: (_) => const VerificationSuccessScreen(),
        );

      case AppRoutes.safetyCenter:
        return MaterialPageRoute(builder: (_) => const SafetyCenterScreen());
      case AppRoutes.trustedContacts:
        return MaterialPageRoute(
          builder: (_) => const TrustedContactsScreen(),
        );
      case AppRoutes.report:
        final target = settings.arguments as Connection?;
        return MaterialPageRoute(
          builder: (_) => ReportScreen(target: target),
        );
      case AppRoutes.premium:
        return MaterialPageRoute(builder: (_) => const PremiumScreen());
      case AppRoutes.notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsScreen());
      case AppRoutes.modePrivacy:
        return MaterialPageRoute(builder: (_) => const ModePrivacyScreen());
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case AppRoutes.support:
        return MaterialPageRoute(builder: (_) => const SupportScreen());
      case AppRoutes.theme:
        return MaterialPageRoute(builder: (_) => const ThemeScreen());
    }
    return null;
  }
}
