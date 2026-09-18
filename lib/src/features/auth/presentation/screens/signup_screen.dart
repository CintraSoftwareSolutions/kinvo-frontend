import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinvo/src/core/assets/app_assets.dart';
import 'package:kinvo/src/core/auth/auth_providers.dart';
import 'package:kinvo/src/core/auth/session_status.dart';
import 'package:kinvo/src/core/demo/demo_mode.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/core/theme/app_colors.dart';
import 'package:kinvo/src/core/time/clock.dart';
import 'package:kinvo/src/core/widgets/flow_widgets.dart';
import 'package:kinvo/src/core/widgets/gradient_scaffold.dart';

import '../controllers/signup_controller.dart';
import '../date_of_birth_picker.dart';

class SignupScreen extends ConsumerWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(signupControllerProvider);
    final controller = ref.read(signupControllerProvider.notifier);
    final editable = !form.isSubmitting;
    final dateOfBirth = form.dateOfBirth;

    // A session starting here means the new details were accepted. Password
    // managers are told now, while the fields are still on screen.
    ref.listen(sessionStatusProvider, (_, status) {
      if (status is SignedIn) TextInput.finishAutofillContext();
    });

    return GradientScaffold(
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
              DemoOnly(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SocialActionCard(
                      title: 'Continue with Google',
                      subtitle: 'Fast signup for demos and imports.',
                      assetName: AppAssets.googleLogo,
                      onTap: () => context.push(AppRoutes.otp),
                    ),
                    const SizedBox(height: 8),
                    SocialActionCard(
                      title: 'Continue with Apple',
                      subtitle:
                          'Privacy-first signup for iPhone-friendly flows.',
                      assetName: AppAssets.appleLogo,
                      onTap: () => context.push(AppRoutes.otp),
                    ),
                    const SizedBox(height: 16),
                    const SectionDivider(label: 'OR USE EMAIL'),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              AutofillGroup(
                onDisposeAction: AutofillContextAction.cancel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppInputCard(
                      label: 'FULL NAME',
                      value: form.displayName,
                      assetName: AppAssets.user,
                      onChanged: controller.updateDisplayName,
                      errorText: form.errors[SignupField.displayName],
                      enabled: editable,
                      autofillHints: const [AutofillHints.name],
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 8),
                    AppInputCard(
                      label: 'EMAIL',
                      value: form.email,
                      assetName: AppAssets.mail,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: controller.updateEmail,
                      errorText: form.errors[SignupField.email],
                      enabled: editable,
                      autocorrect: false,
                      // The email is the username, so password managers save
                      // the new password against it.
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 8),
                    PasswordInputCard(
                      label: 'PASSWORD',
                      value: form.password,
                      onChanged: controller.updatePassword,
                      isNewPassword: true,
                      errorText: form.errors[SignupField.password],
                      enabled: editable,
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              AppPickerCard(
                label: 'DATE OF BIRTH',
                value: dateOfBirth == null
                    ? null
                    : formatDateOfBirth(context, dateOfBirth),
                placeholder: 'Select your date of birth',
                icon: Icons.cake_outlined,
                errorText: form.errors[SignupField.dateOfBirth],
                enabled: editable,
                onTap: () => unawaited(_pickDateOfBirth(context, ref)),
              ),
              const SizedBox(height: 14),
              const InfoBanner(
                title: 'Trust-first onboarding',
                description:
                    'Verification, privacy controls, and trusted contacts can all be added later.',
                backgroundColor: Color(0xFFEAF2FF),
                iconColor: AppColors.blue,
              ),
              if (form.formError case final message?) ...[
                const SizedBox(height: 14),
                FormErrorBanner(message: message),
              ],
              const SizedBox(height: 14),
              PrimaryActionButton(
                label: 'Create account',
                loading: form.isSubmitting,
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  unawaited(controller.submit());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateOfBirth(BuildContext context, WidgetRef ref) async {
    FocusScope.of(context).unfocus();
    final picked = await pickDateOfBirth(
      context,
      today: ref.read(clockProvider)(),
      initial: ref.read(signupControllerProvider).dateOfBirth,
    );
    if (picked == null || !context.mounted) return;

    ref.read(signupControllerProvider.notifier).updateDateOfBirth(picked);
  }
}
