import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/account_providers.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/session_status.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../core/widgets/kinvo_logo.dart';

/// Shown while the saved session is read and the account loads.
///
/// If the account can't be loaded, explains why and offers to try again or
/// sign out, rather than leaving the user on a spinner.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionStatusProvider);
    final account = ref.watch(currentAccountProvider);
    final failure =
        session is SignedIn && account.hasError && !account.isLoading
        ? account.error
        : null;

    return GradientScaffold(
      background: AppColors.welcomeBackground,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const KinvoLogo(),
            const SizedBox(height: 32),
            if (failure == null)
              const SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                  semanticsLabel: 'Loading',
                ),
              )
            else
              _LoadFailure(
                message: failure is ApiException
                    ? failure.message
                    : 'Something went wrong. Please try again.',
                onRetry: () => ref.invalidate(currentAccountProvider),
                onSignOut: () =>
                    unawaited(ref.read(sessionManagerProvider).signOut()),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({
    required this.message,
    required this.onRetry,
    required this.onSignOut,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(
            color: Colors.white,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.purple,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text('Try again'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onSignOut,
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}
