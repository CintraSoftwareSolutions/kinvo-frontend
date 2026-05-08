import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class DevicePreviewShell extends StatelessWidget {
  const DevicePreviewShell({
    required this.child,
    required this.background,
    super.key,
  });

  final Widget child;
  final Gradient background;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: background),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SizedBox.expand(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
