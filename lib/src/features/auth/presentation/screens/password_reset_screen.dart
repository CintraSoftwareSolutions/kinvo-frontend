import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinvo/src/core/assets/app_assets.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/core/theme/app_colors.dart';
import 'package:kinvo/src/core/widgets/flow_widgets.dart';
import 'package:kinvo/src/core/widgets/gradient_scaffold.dart';

import '../controllers/password_reset_controller.dart';

/// Step one of a forgotten password: where to send the code.
class PasswordResetScreen extends ConsumerWidget {
  const PasswordResetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(resetRequestControllerProvider);
    final controller = ref.read(resetRequestControllerProvider.notifier);

    Future<void> submit() async {
      FocusScope.of(context).unfocus();
      final sent = await controller.submit();
      if (!sent || !context.mounted) return;
      await context.push(AppRoutes.newPassword);
    }

    return GradientScaffold(
      background: AppColors.lightBackground,
      child: FlowPageLayout(
        badgeText: 'Account recovery',
        badgeAsset: AppAssets.lock,
        title: 'Reset your password',
        subtitle:
            'Tell us the address on your account and we will email you a code '
            'to set a new password with.',
        content: SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const InfoBanner(
                title: 'Protected recovery',
                description:
                    'The code lasts an hour and works once. Nothing about your '
                    'profile changes until you choose a new password.',
              ),
              const SizedBox(height: 10),
              AppInputCard(
                label: 'EMAIL',
                value: form.email,
                assetName: AppAssets.mail,
                keyboardType: TextInputType.emailAddress,
                onChanged: controller.updateEmail,
                errorText: form.errors[ResetRequestField.email],
                enabled: !form.isSubmitting,
                autocorrect: false,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => submit(),
              ),
              if (form.formError case final message?) ...[
                const SizedBox(height: 12),
                FormErrorBanner(message: message),
              ],
              const SizedBox(height: 14),
              PrimaryActionButton(
                label: 'Send code',
                loading: form.isSubmitting,
                onPressed: submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
