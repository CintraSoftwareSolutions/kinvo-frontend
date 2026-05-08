import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinvo/src/core/assets/app_assets.dart';
import 'package:kinvo/src/core/theme/app_colors.dart';
import 'package:kinvo/src/core/widgets/device_preview_shell.dart';
import 'package:kinvo/src/core/widgets/flow_widgets.dart';

import '../controllers/auth_controllers.dart';

class PasswordResetScreen extends ConsumerWidget {
  const PasswordResetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(passwordResetControllerProvider);
    final controller = ref.read(passwordResetControllerProvider.notifier);

    return DevicePreviewShell(
      background: AppColors.lightBackground,
      child: FlowPageLayout(
        badgeText: 'Account recovery',
        badgeAsset: AppAssets.lock,
        title: 'Reset your password',
        subtitle:
            'Send a secure reset link to your email so you can recover access without losing your profile setup.',
        content: SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const InfoBanner(
                title: 'Protected recovery',
                description:
                    'Reset links are scoped to your email and expire quickly for safety.',
              ),
              const SizedBox(height: 10),
              AppInputCard(
                label: 'EMAIL',
                value: state.email,
                assetName: AppAssets.mail,
                keyboardType: TextInputType.emailAddress,
                onChanged: controller.updateEmail,
              ),
              const SizedBox(height: 14),
              PrimaryActionButton(
                label: 'Send reset link',
                onPressed: state.canSend ? controller.sendResetLink : null,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  color: AppColors.greenSoft.withOpacity(.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppColors.green,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Check your email',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: AppColors.green,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'A reset link has been sent and can bring you back to login once completed.',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: AppColors.green,
                                  fontSize: 11.5,
                                  height: 1.45,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
