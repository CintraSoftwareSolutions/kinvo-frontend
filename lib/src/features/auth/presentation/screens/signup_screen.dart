import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinvo/src/core/assets/app_assets.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/core/theme/app_colors.dart';
import 'package:kinvo/src/core/widgets/device_preview_shell.dart';
import 'package:kinvo/src/core/widgets/flow_widgets.dart';

import '../controllers/auth_controllers.dart';

class SignupScreen extends ConsumerWidget {
  const SignupScreen({super.key});

  static const _modes = [
    'Dating',
    'Networking',
    'Study Buddy',
    'Foodie',
    'Fitness',
    'Trading',
    'Pets',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(signupFormControllerProvider);
    final controller = ref.read(signupFormControllerProvider.notifier);

    return DevicePreviewShell(
      background: AppColors.lightBackground,
      child: FlowPageLayout(
        badgeText: 'Kinvo',
        badgeIcon: Icons.favorite_rounded,
        title: 'Create your account',
        subtitle:
            'Build one trusted profile for dating, networking, study plans, foodie matches, and more.',
        content: SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SocialActionCard(
                title: 'Continue with Google',
                subtitle: 'Fast signup for demos and imports.',
                assetName: AppAssets.googleLogo,
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.otp),
              ),
              const SizedBox(height: 8),
              SocialActionCard(
                title: 'Continue with Apple',
                subtitle: 'Privacy-first signup for iPhone-friendly flows.',
                assetName: AppAssets.appleLogo,
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.otp),
              ),
              const SizedBox(height: 16),
              const SectionDivider(label: 'OR USE EMAIL'),
              const SizedBox(height: 12),
              AppInputCard(
                label: 'FULL NAME',
                value: state.fullName,
                assetName: AppAssets.user,
                onChanged: controller.updateFullName,
              ),
              const SizedBox(height: 8),
              AppInputCard(
                label: 'EMAIL',
                value: state.email,
                assetName: AppAssets.mail,
                keyboardType: TextInputType.emailAddress,
                onChanged: controller.updateEmail,
              ),
              const SizedBox(height: 8),
              AppInputCard(
                label: 'PASSWORD',
                value: state.password,
                assetName: AppAssets.lock,
                obscureText: true,
                onChanged: controller.updatePassword,
              ),
              const SizedBox(height: 14),
              Text(
                'Primary mode',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mode in _modes)
                    OptionChip(
                      label: mode,
                      selected: state.primaryMode == mode,
                      onTap: () => controller.selectPrimaryMode(mode),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const InfoBanner(
                title: 'Trust-first onboarding',
                description:
                    'Verification, privacy controls, and trusted contacts can all be added later.',
                backgroundColor: Color(0xFFEAF2FF),
                iconColor: AppColors.blue,
              ),
              const SizedBox(height: 14),
              PrimaryActionButton(
                label: 'Continue to OTP',
                onPressed: state.canContinue
                    ? () => Navigator.of(context).pushNamed(AppRoutes.otp)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
