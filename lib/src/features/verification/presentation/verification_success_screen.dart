import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/kinvo_colors.dart';
import '../../../core/widgets/flow_widgets.dart';
import '../../../core/widgets/page_header.dart';
import '../domain/verification.dart';
import 'controllers/verification_controller.dart';
import 'widgets/verification_widgets.dart';

/// Step 3: it has been sent, and a person will decide.
///
/// Deliberately not called "verified": nothing has been approved yet, and a
/// screen that says otherwise would be telling the user something the product
/// cannot promise.
class VerificationSuccessScreen extends ConsumerWidget {
  const VerificationSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verification = ref.watch(verificationProvider).value;
    final isId = verification?.method == VerificationMethod.governmentId;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Verification',
              subtitle: 'Step 3 of 3',
              leading: HeaderBackButton(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            ),
            const VerificationSteps(stepIndex: 2),
            Divider(height: 1, color: context.colors.divider),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 26, 18, 24),
                child: Column(
                  children: [
                    VerificationBadge(
                      asset: AppAssets.checkCircle,
                      background: context.colors.tint(Hue.green).soft,
                      foreground: context.colors.tint(Hue.green).color,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Sent for review',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isId
                          ? 'A moderator will check your ID and let you know. '
                                'It is stored apart from your photos and is '
                                'never shown on your profile.'
                          : 'A moderator will check your selfie against your '
                                'photos and let you know.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: context.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    VerificationTips(
                      title: 'What happens next',
                      background: context.colors.surfaceSoft,
                      titleColor: context.colors.textPrimary,
                      tips: const [
                        'We tell you either way, by notification.',
                        'Approved, and the badge appears on your profile '
                            'straight away.',
                        'Turned down, and you can try again with a clearer '
                            'photo.',
                      ],
                    ),
                    const SizedBox(height: 20),
                    PrimaryActionButton(
                      label: 'Done',
                      // Back past the camera to the verification screen, which
                      // now shows that it is waiting.
                      onPressed: () => context.pop(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
