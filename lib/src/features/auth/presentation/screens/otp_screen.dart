import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinvo/src/core/assets/app_assets.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/core/theme/app_colors.dart';
import 'package:kinvo/src/core/widgets/device_preview_shell.dart';
import 'package:kinvo/src/core/widgets/flow_widgets.dart';
import 'package:pinput/pinput.dart';

import '../controllers/auth_controllers.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  late final TextEditingController _pinController;
  late final FocusNode _pinFocusNode;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController(
      text: ref.read(otpControllerProvider).pin,
    );
    _pinFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(otpControllerProvider);
    final controller = ref.read(otpControllerProvider.notifier);

    final defaultPinTheme = PinTheme(
      width: 44,
      height: 48,
      textStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.purple, width: 1.6),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
      ),
    );

    return DevicePreviewShell(
      background: AppColors.lightBackground,
      child: FlowPageLayout(
        badgeText: 'OTP verification',
        badgeAsset: AppAssets.otpBadge,
        title: 'Verify your number',
        subtitle:
            'Confirm your signup with a one-time code so the account starts with a stronger trust signal.',
        content: SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const InfoBanner(
                title: 'Code sent to +1 (555) 401-8892',
                description:
                    'Demo code is prefilled for export and prototype flow.',
              ),
              const SizedBox(height: 14),
              Center(
                child: Pinput(
                  length: 6,
                  controller: _pinController,
                  focusNode: _pinFocusNode,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  submittedPinTheme: submittedPinTheme,
                  separatorBuilder: (_) => const SizedBox(width: 6),
                  showCursor: true,
                  keyboardType: TextInputType.number,
                  pinAnimationType: PinAnimationType.fade,
                  onChanged: controller.updatePin,
                ),
              ),
              const SizedBox(height: 14),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SmallInfoCard(
                        title: 'Expires in ${state.formattedTime}',
                        description:
                            'Short-lived OTP window to reduce fraud risk.',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SmallInfoCard(
                        title: 'Resend available',
                        description:
                            'Can switch to email or resend SMS if delivery fails.',
                        onTap: () {
                          _pinController.clear();
                          controller.resendCode();
                          _pinFocusNode.requestFocus();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              PrimaryActionButton(
                label: 'Verify code',
                onPressed: state.canVerify
                    ? () =>
                          Navigator.of(context).pushNamed(AppRoutes.onboarding)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
