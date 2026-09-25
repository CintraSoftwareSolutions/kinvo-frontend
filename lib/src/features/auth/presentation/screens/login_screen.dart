import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinvo/src/core/assets/app_assets.dart';
import 'package:kinvo/src/core/auth/auth_providers.dart';
import 'package:kinvo/src/core/auth/session_status.dart';
import 'package:kinvo/src/core/config/server_config_providers.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/core/theme/app_colors.dart';
import 'package:kinvo/src/core/widgets/flow_widgets.dart';
import 'package:kinvo/src/core/widgets/gradient_scaffold.dart';

import '../controllers/login_controller.dart';
import '../controllers/social_sign_in_controller.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(loginControllerProvider);
    final controller = ref.read(loginControllerProvider.notifier);
    final editable = !form.isSubmitting;
    final googleState = ref.watch(socialSignInControllerProvider);
    final social = ref.read(socialSignInControllerProvider.notifier);
    final methods = ref.watch(signInMethodsProvider);
    final usePhone = methods.phone;
    // This build must be set up for Google as well as the server.
    final useGoogle = methods.google && social.canUseGoogle;

    // A session starting here means the details were accepted. Password
    // managers are told now, while the fields are still on screen.
    ref.listen(sessionStatusProvider, (_, status) {
      if (status is SignedIn) TextInput.finishAutofillContext();
    });

    void submit() {
      FocusScope.of(context).unfocus();
      unawaited(controller.submit());
    }

    return GradientScaffold(
      background: AppColors.lightBackground,
      child: FlowPageLayout(
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
              AutofillGroup(
                onDisposeAction: AutofillContextAction.cancel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppInputCard(
                      label: 'EMAIL',
                      value: form.email,
                      assetName: AppAssets.mail,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: controller.updateEmail,
                      errorText: form.errors[LoginField.email],
                      enabled: editable,
                      autocorrect: false,
                      // The email is the username password managers file the
                      // password under.
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 10),
                    PasswordInputCard(
                      label: 'PASSWORD',
                      value: form.password,
                      onChanged: controller.updatePassword,
                      errorText: form.errors[LoginField.password],
                      enabled: editable,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => submit(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _RememberDeviceToggle(
                      value: form.rememberDevice,
                      onChanged: editable ? controller.setRememberDevice : null,
                    ),
                  ),
                  Semantics(
                    button: true,
                    child: GestureDetector(
                      // The address is carried across, so it isn't typed twice.
                      onTap: () => context.push(AppRoutes.resetPassword),
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        'Forgot password?',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.purple,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (form.formError case final message?) ...[
                const SizedBox(height: 14),
                FormErrorBanner(message: message),
              ],
              const SizedBox(height: 14),
              PrimaryActionButton(
                label: 'Sign in',
                loading: form.isSubmitting,
                onPressed: submit,
              ),
              // Only the ways the server says it can complete: a button that
              // can only fail is worse than none.
              if (usePhone || useGoogle) ...[
                const SizedBox(height: 16),
                const SectionDivider(label: 'OR'),
              ],
              // The server texts a code, and a number with no account gets
              // one.
              if (usePhone) ...[
                const SizedBox(height: 14),
                OutlineActionButton(
                  label: 'Continue with your phone number',
                  // The card underneath is white, and this button defaults to
                  // white on white.
                  foregroundColor: AppColors.purple,
                  borderColor: AppColors.border,
                  onPressed: editable
                      ? () => context.push(AppRoutes.phoneSignIn)
                      : null,
                ),
              ],
              // Google proves who they are; the server decides what that
              // means here. A Google account with no Kinvo account gets
              // one, the same as a new phone number does.
              if (useGoogle) ...[
                SizedBox(height: usePhone ? 10 : 14),
                SocialActionCard(
                  title: 'Continue with Google',
                  subtitle: 'No password to remember.',
                  assetName: AppAssets.googleLogo,
                  onTap: googleState.isBusy || !editable
                      ? null
                      : () => unawaited(social.signInWithGoogle()),
                ),
                if (googleState.error case final message?) ...[
                  const SizedBox(height: 12),
                  FormErrorBanner(message: message),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Remember this device", with the whole row as the tap target.
class _RememberDeviceToggle extends StatelessWidget {
  const _RememberDeviceToggle({required this.value, required this.onChanged});

  static const _label = 'Remember this device';

  final bool value;

  /// `null` while the form can't be changed.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    final toggle = onChanged == null ? null : () => onChanged(!value);

    return Semantics(
      checked: value,
      enabled: onChanged != null,
      label: _label,
      onTap: toggle,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: toggle,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            CircleToggle(value: value, onChanged: null),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
