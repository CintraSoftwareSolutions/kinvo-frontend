import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';

class VerificationMethodsScreen extends StatelessWidget {
  const VerificationMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Verification',
              subtitle: 'Step 1 of 3',
              leading: HeaderBackButton(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            ),
            const _StepProgress(stepIndex: 0),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 28, 18, 24),
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF6366F1),
                            Color(0xFF818CF8),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x336366F1),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          AppAssets.shield,
                          width: 26,
                          height: 26,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Get Verified',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Choose the best trust signal for your profile.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _MethodCard(
                      icon: AppAssets.camera,
                      iconBg: const Color(0xFFE0E7FF),
                      iconColor: const Color(0xFF6366F1),
                      title: 'Photo Verification',
                      subtitle: 'Take a live selfie. Recommended and fast.',
                      meta: 'Recommended | 2 min',
                      onTap: () => context.push(AppRoutes.verificationCapture),
                    ),
                    const SizedBox(height: 10),
                    _MethodCard(
                      icon: AppAssets.upload,
                      iconBg: const Color(0xFFEDE9FE),
                      iconColor: AppColors.purple,
                      title: 'ID Verification',
                      subtitle: 'Upload a government-issued ID.',
                      meta: 'Takes 3-5 min',
                      onTap: () => context.push(AppRoutes.verificationCapture),
                    ),
                    const SizedBox(height: 10),
                    _MethodCard(
                      icon: AppAssets.bolt,
                      iconBg: const Color(0xFFD1FAE5),
                      iconColor: const Color(0xFF10B981),
                      title: 'Social Verification',
                      subtitle: 'Link a social profile for quick validation.',
                      meta: 'Instant for networking',
                      onTap: () => context.push(AppRoutes.verificationSuccess),
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

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.stepIndex});

  final int stepIndex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Row(
        children: [
          for (int i = 0; i < 3; i++) ...[
            Expanded(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: i <= stepIndex
                      ? AppColors.purple
                      : AppColors.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            if (i < 2) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.onTap,
  });

  final String icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: SvgPicture.asset(
                  icon,
                  width: 18,
                  height: 18,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meta,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
