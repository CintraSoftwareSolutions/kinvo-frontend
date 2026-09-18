import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/session_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/flow_widgets.dart';
import '../../../core/widgets/gradient_scaffold.dart';

/// The only screen a suspended account can reach.
class AccountSuspendedScreen extends ConsumerWidget {
  const AccountSuspendedScreen({super.key});

  static const _defaultMessage = 'Your account has been suspended.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(sessionStatusProvider);
    final message = status is AccountSuspended && status.message.isNotEmpty
        ? status.message
        : _defaultMessage;

    return GradientScaffold(
      background: AppColors.lightBackground,
      child: FlowPageLayout(
        backButton: const SizedBox.shrink(),
        backButtonSpacing: 0,
        badgeText: 'Account',
        badgeAsset: AppAssets.shield,
        title: 'Your account is suspended',
        subtitle: message,
        content: SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const InfoBanner(
                title: 'Think this is a mistake?',
                description:
                    'Contact Kinvo support from the email address on your '
                    'account and we will review it.',
              ),
              const SizedBox(height: 14),
              PrimaryActionButton(
                label: 'Sign out',
                onPressed: () =>
                    unawaited(ref.read(sessionManagerProvider).signOut()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
