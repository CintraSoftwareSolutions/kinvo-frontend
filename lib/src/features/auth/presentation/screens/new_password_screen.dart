import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinvo/src/core/assets/app_assets.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/core/theme/app_colors.dart';
import 'package:kinvo/src/core/widgets/flow_widgets.dart';
import 'package:kinvo/src/core/widgets/gradient_scaffold.dart';

import '../../data/password_reset_service.dart';
import '../controllers/new_password_controller.dart';
import '../controllers/password_reset_controller.dart';

/// Step two of a forgotten password: the code from the email, and the password
/// that replaces the forgotten one.
class NewPasswordScreen extends ConsumerWidget {
  const NewPasswordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingPasswordResetProvider);
    final form = ref.watch(newPasswordControllerProvider);
    final controller = ref.read(newPasswordControllerProvider.notifier);

    // Nothing has been sent — the user arrived here by a link, or the app
    // restarted mid-flow. The router sends them back; this is the frame before
    // it does.
    if (pending == null) return const SizedBox.shrink();

    Future<void> submit() async {
      FocusScope.of(context).unfocus();
      final outcome = await controller.submit();
      if (outcome == null || !context.mounted) return;

      switch (outcome) {
        // The session started, and the router follows it into the app.
        case PasswordResetOutcome.signedIn:
          break;
        case PasswordResetOutcome.signInRequired:
          context.go(AppRoutes.login);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your password is changed. Please log in.'),
            ),
          );
      }
    }

    return GradientScaffold(
      background: AppColors.lightBackground,
      child: FlowPageLayout(
        badgeText: 'Account recovery',
        badgeAsset: AppAssets.lock,
        title: 'Choose a new password',
        subtitle:
            'If ${pending.email} has an account, a six-digit code is on its '
            'way there. It lasts an hour.',
        content: SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppInputCard(
                // A resend retires the old code, so the field starts again
                // with it rather than keeping digits that no longer work.
                key: ValueKey(pending.sentAt),
                label: 'CODE FROM EMAIL',
                value: form.code,
                hintText: '123456',
                assetName: AppAssets.lock,
                keyboardType: TextInputType.number,
                onChanged: controller.updateCode,
                errorText: form.errors[NewPasswordField.code],
                enabled: !form.isBusy,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.oneTimeCode],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 10),
              PasswordInputCard(
                label: 'NEW PASSWORD',
                value: form.password,
                isNewPassword: true,
                onChanged: controller.updatePassword,
                errorText: form.errors[NewPasswordField.password],
                enabled: !form.isBusy,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => submit(),
              ),
              if (form.notice case final message?) ...[
                const SizedBox(height: 12),
                _Notice(message: message),
              ],
              if (form.formError case final message?) ...[
                const SizedBox(height: 12),
                FormErrorBanner(message: message),
              ],
              const SizedBox(height: 14),
              PrimaryActionButton(
                label: 'Save new password',
                loading: form.isSubmitting,
                onPressed: submit,
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: form.isBusy ? null : controller.resend,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.purple,
                    textStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(
                    form.isResending ? 'Sending…' : 'Send another code',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Something that went right, in the same shape as [FormErrorBanner].
class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.greenSoft.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.check_circle_outline_rounded,
                size: 16,
                color: AppColors.green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.green,
                  fontSize: 12.5,
                  height: 1.45,
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
