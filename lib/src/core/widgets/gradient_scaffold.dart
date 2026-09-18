import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Full-screen scaffold with a brand gradient behind safe-area content.
///
/// The child always fills the space inside the safe area, so the gradient
/// covers the whole screen even when the content itself is shorter.
class GradientScaffold extends StatelessWidget {
  const GradientScaffold({
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
        child: SafeArea(child: SizedBox.expand(child: child)),
      ),
    );
  }
}
