import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/media/photo_picker.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/photo_source_sheet.dart';
import '../../../core/widgets/flow_widgets.dart';
import '../../../core/widgets/page_header.dart';
import '../domain/verification.dart';
import 'controllers/verification_controller.dart';
import 'widgets/verification_widgets.dart';

/// Step 2: take the selfie or photograph the ID, then send it.
///
/// The picture is shown back from the bytes that were uploaded, not from the
/// server. Documents live in a private bucket behind short-lived URLs, and
/// there is no reason for the app to read one back.
class VerificationCaptureScreen extends ConsumerWidget {
  const VerificationCaptureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verification = ref.watch(verificationProvider).value;
    final draft = ref.watch(verificationDraftProvider);
    final isId = verification?.method == VerificationMethod.governmentId;

    Future<void> choose() async {
      final source = isId
          ? await showPhotoSourceSheet(context)
          : PhotoSource.selfie;
      if (source == null || !context.mounted) return;

      await ref.read(verificationProvider.notifier).chooseDocument(source);
    }

    Future<void> send() async {
      final sent = await ref.read(verificationProvider.notifier).submit();
      if (sent && context.mounted) {
        // Replaces this screen: going back to the camera after sending would
        // offer to change something that is already with a moderator.
        context.pushReplacement(AppRoutes.verificationSuccess);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Verification',
              subtitle: 'Step 2 of 3',
              leading: HeaderBackButton(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            ),
            const VerificationSteps(stepIndex: 1),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Text(
                        isId ? 'Photograph your ID' : 'Take a selfie',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        isId
                            ? 'A passport, driving licence or ID card, with '
                                  'all four corners in shot.'
                            : 'Look at the camera, with your face lit and '
                                  'nothing covering it.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    AspectRatio(
                      aspectRatio: isId ? 1.45 : 0.95,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: switch (draft.document) {
                            final document? => ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.memory(
                                document.bytes,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                            _ => _Placeholder(isId: isId),
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    VerificationTips(
                      title: 'Tips for best results',
                      tips: isId
                          ? const [
                              'Lay it flat, with no fingers over the details',
                              'Avoid glare from a window or a lamp',
                              'Make sure the text is readable',
                              'The name must match the one on your profile',
                            ]
                          : const [
                              'Face the camera directly',
                              'Take off hats and sunglasses',
                              'Keep a neutral expression',
                              'Avoid dark rooms and backlighting',
                            ],
                    ),
                    if (draft.error case final message?) ...[
                      const SizedBox(height: 14),
                      FormErrorBanner(message: message),
                    ],
                    const SizedBox(height: 14),
                    if (draft.document == null)
                      PrimaryActionButton(
                        label: isId ? 'Add a photo of your ID' : 'Take a photo',
                        loading: draft.isBusy,
                        onPressed: draft.isBusy
                            ? null
                            : () => unawaited(choose()),
                      )
                    else ...[
                      PrimaryActionButton(
                        label: 'Send for review',
                        loading: draft.isBusy,
                        onPressed: draft.isBusy
                            ? null
                            : () => unawaited(send()),
                      ),
                      const SizedBox(height: 8),
                      OutlineActionButton(
                        label: isId ? 'Take another photo' : 'Retake',
                        onPressed: draft.isBusy
                            ? null
                            : () => unawaited(choose()),
                      ),
                    ],
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

/// The empty frame before anything is taken.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.isId});

  final bool isId;

  @override
  Widget build(BuildContext context) {
    final label = isId ? 'Fit your ID in the frame' : 'Position your face here';

    return CustomPaint(
      painter: _DashedOutline(isId: isId),
      child: SizedBox(
        width: isId ? 260 : 200,
        height: isId ? 170 : 260,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                AppAssets.camera,
                width: 32,
                height: 32,
                colorFilter: const ColorFilter.mode(
                  AppColors.textMuted,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An oval for a face, a rectangle for a card.
class _DashedOutline extends CustomPainter {
  const _DashedOutline({required this.isId});

  final bool isId;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * (isId ? 0.96 : 0.82),
      height: size.height * (isId ? 0.96 : 1.1),
    );
    final path = Path();
    if (isId) {
      path.addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)));
    } else {
      path.addOval(rect);
    }

    for (final metric in path.computeMetrics()) {
      var start = 0.0;
      while (start < metric.length) {
        final end = start + 6 > metric.length ? metric.length : start + 6;
        canvas.drawPath(metric.extractPath(start, end), paint);
        start += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedOutline oldDelegate) =>
      oldDelegate.isId != isId;
}
