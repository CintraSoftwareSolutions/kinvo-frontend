import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinvo/src/core/assets/app_assets.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/core/theme/app_colors.dart';
import 'package:kinvo/src/core/widgets/device_preview_shell.dart';
import 'package:kinvo/src/core/widgets/flow_widgets.dart';

import '../controllers/auth_controllers.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const DevicePreviewShell(
      background: AppColors.lightBackground,
      child: _LoginContent(),
    );
  }
}

class _LoginContent extends ConsumerWidget {
  const _LoginContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loginFormControllerProvider);
    final controller = ref.read(loginFormControllerProvider.notifier);

    return FlowPageLayout(
      badgeText: 'Welcome back',
      badgeIcon: Icons.favorite_rounded,
      title: 'Log in to Kinvo',
      subtitle:
          'Pick up your matches, plans, and safety tools exactly where you left them.',
      content: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const InfoBanner(
              title: 'Safe sign-in',
              description:
                  'Keeps your preferences, premium state, and trusted contacts ready across sessions.',
            ),
            const SizedBox(height: 10),
            AppInputCard(
              label: 'EMAIL',
              value: state.email,
              assetName: AppAssets.mail,
              keyboardType: TextInputType.emailAddress,
              onChanged: controller.updateEmail,
            ),
            const SizedBox(height: 10),
            AppInputCard(
              label: 'PASSWORD',
              value: state.password,
              assetName: AppAssets.lock,
              obscureText: true,
              onChanged: controller.updatePassword,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleToggle(
                  value: state.rememberDevice,
                  onChanged: controller.toggleRememberDevice,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Remember this device',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.resetPassword),
                  child: Text(
                    'Forgot password?',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.purple,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            PrimaryActionButton(
              label: 'Sign in',
              onPressed: state.canSubmit
                  ? () => Navigator.of(context).pushNamed(AppRoutes.onboarding)
                  : null,
            ),
            const SizedBox(height: 16),
            const SectionDivider(label: 'QUICK ACCESS'),
            const SizedBox(height: 14),
            const Row(
              children: [
                Expanded(
                  child: SmallInfoCard(
                    title: 'Apple',
                    description: 'Fast sign-in for iOS demos.',
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: SmallInfoCard(
                    title: 'Google',
                    description: 'Use your workspace identity.',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
