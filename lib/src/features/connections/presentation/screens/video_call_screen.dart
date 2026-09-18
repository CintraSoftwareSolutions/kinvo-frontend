import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../domain/connection.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({required this.connection, super.key});

  final Connection connection;

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  Timer? _timer;
  int _seconds = 0;
  bool _muted = false;
  bool _speakerOn = true;
  bool _cameraOn = true;
  bool _flagged = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _time {
    final h = _seconds ~/ 3600;
    final m = (_seconds ~/ 60) % 60;
    final s = _seconds % 60;
    return h > 0
        ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.connection;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                c.avatar,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: const Color(0xFF1F2937),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    stops: const [0, 0.4, 1],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Secure call',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _time,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'End-to-end encrypted',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFFBBF24),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Need help during the call?',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Open safety actions, send a live update, or end and report instantly.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.4,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _CallButton(
                        icon: AppAssets.mic,
                        active: !_muted,
                        toggleableOff: _muted,
                        onTap: () => setState(() => _muted = !_muted),
                      ),
                      _CallButton(
                        icon: AppAssets.speaker,
                        active: _speakerOn,
                        toggleableOff: !_speakerOn,
                        onTap: () =>
                            setState(() => _speakerOn = !_speakerOn),
                      ),
                      _CallButton(
                        icon: AppAssets.cameraWhite,
                        active: _cameraOn,
                        toggleableOff: !_cameraOn,
                        onTap: () =>
                            setState(() => _cameraOn = !_cameraOn),
                      ),
                      _CallButton(
                        icon: AppAssets.flagWhite,
                        active: _flagged,
                        background: _flagged
                            ? const Color(0xFF92400E)
                            : Colors.white24,
                        onTap: () {
                          setState(() => _flagged = true);
                          context.push(AppRoutes.report(connectionId: c.id));
                        },
                      ),
                      _CallButton(
                        icon: AppAssets.phoneHangup,
                        background: const Color(0xFFEF4458),
                        size: 56,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              right: 16,
              top: 96,
              child: _SelfPreview(camera: _cameraOn),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.onTap,
    this.active = true,
    this.toggleableOff = false,
    this.background,
    this.size = 48,
  });

  final String icon;
  final VoidCallback onTap;
  final bool active;
  final bool toggleableOff;
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background ?? Colors.white24,
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SvgPicture.asset(
              icon,
              width: size * 0.42,
              height: size * 0.42,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
            if (toggleableOff)
              Transform.rotate(
                angle: -0.78,
                child: Container(
                  width: size * 0.7,
                  height: 2,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelfPreview extends StatelessWidget {
  const _SelfPreview({required this.camera});

  final bool camera;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 128,
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      clipBehavior: Clip.antiAlias,
      child: camera
          ? Image.asset(
              AppAssets.avatarBill,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Color(0xFF1F2937),
                child: Center(
                  child: Icon(Icons.person, color: Colors.white24, size: 40),
                ),
              ),
            )
          : const ColoredBox(
              color: Color(0xFF111827),
              child: Center(
                child: Icon(
                  Icons.videocam_off_rounded,
                  color: Colors.white54,
                ),
              ),
            ),
    );
  }
}
