import 'package:flutter/material.dart';

import 'core/navigation/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/otp_screen.dart';
import 'features/auth/presentation/screens/password_reset_screen.dart';
import 'features/auth/presentation/screens/signup_screen.dart';
import 'features/onboarding/presentation/screens/profile_setup_screen.dart';
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
      routes: {
        AppRoutes.welcome: (_) => const WelcomeScreen(),
        AppRoutes.signup: (_) => const SignupScreen(),
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.otp: (_) => const OtpScreen(),
        AppRoutes.resetPassword: (_) => const PasswordResetScreen(),
        AppRoutes.onboarding: (_) => const ProfileSetupScreen(),
      },
    );
  }
}
