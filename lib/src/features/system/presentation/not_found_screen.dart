import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/flow_widgets.dart';
import '../../../core/widgets/gradient_scaffold.dart';

/// Shown for a link to a location that doesn't exist, or to something no
/// longer available, such as a conversation that was removed.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      background: AppColors.lightBackground,
      child: FlowPageLayout(
        backButton: const SizedBox.shrink(),
        backButtonSpacing: 0,
        badgeText: 'Not found',
        badgeIcon: Icons.search_off_rounded,
        title: "This page isn't available",
        subtitle: 'It may have been removed, or the link may be wrong.',
        content: PrimaryActionButton(
          label: 'Go to Discover',
          onPressed: () => context.go(AppRoutes.discover),
        ),
      ),
    );
  }
}
