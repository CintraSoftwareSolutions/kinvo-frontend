import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';

class VerificationCaptureScreen extends StatefulWidget {
  const VerificationCaptureScreen({super.key});

  @override
  State<VerificationCaptureScreen> createState() =>
      _VerificationCaptureScreenState();
}

class _VerificationCaptureScreenState extends State<VerificationCaptureScreen> {
  String? _path;

  Future<void> _capture() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 80,
      );
      if (picked == null || !mounted) return;
      setState(() => _path = picked.path);
      unawaited(context.push<void>(AppRoutes.verificationSuccess));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera not available: $e')),
      );
    }
  }

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
              subtitle: 'Step 2 of 3',
              leading: HeaderBackButton(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            ),
            const _StepProgress(stepIndex: 1),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: Text(
                        'Take a Selfie',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Center(
                      child: Text(
                        'Center your face and keep your lighting clear.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    AspectRatio(
                      aspectRatio: 0.95,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: _path == null
                              ? const _Outline()
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.file(
                                    File(_path!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE4E8),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Tips for best results',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB91C1C),
                            ),
                          ),
                          SizedBox(height: 6),
                          _Bullet(text: 'Face the camera directly'),
                          _Bullet(text: 'Remove hats and glasses'),
                          _Bullet(text: 'Use a neutral expression'),
                          _Bullet(text: 'Avoid dark rooms or backlighting'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _capture,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Take Photo'),
                      ),
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

class _Outline extends StatelessWidget {
  const _Outline();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OvalDashPainter(),
      child: SizedBox(
        width: 200,
        height: 260,
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
              const Text(
                'Position your face here',
                style: TextStyle(
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

class _OvalDashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.82,
      height: size.height * 1.1,
    );
    final path = Path()..addOval(rect);
    final pm = path.computeMetrics();
    for (final m in pm) {
      double i = 0;
      while (i < m.length) {
        final next = i + 6 > m.length ? m.length : i + 6;
        final extract = m.extractPath(i, next);
        canvas.drawPath(extract, paint);
        i += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.stepIndex});

  final int stepIndex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
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


class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '• ',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFFB91C1C),
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Color(0xFFB91C1C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
