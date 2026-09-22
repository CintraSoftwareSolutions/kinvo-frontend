import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/time/clock.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/time/relative_time.dart';
import '../../../core/widgets/flow_widgets.dart';
import '../../../core/widgets/page_header.dart';
import '../domain/verification.dart';
import 'controllers/verification_controller.dart';
import 'widgets/verification_widgets.dart';

/// Verification: the badge, and how to get it.
///
/// One screen for every state the check can be in — never started, half done,
/// waiting for a moderator, approved, rejected — because they are the same
/// question ("where is my badge?") and a user arriving from a notification
/// must land on the answer rather than on a form.
class VerificationMethodsScreen extends ConsumerWidget {
  const VerificationMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verification = ref.watch(verificationProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Verification',
              subtitle: switch (verification.value) {
                final state? when state.isVerified => 'Approved',
                final state? when state.isAwaitingReview => 'Step 3 of 3',
                final state? when state.isUnfinished => 'Step 1 of 3',
                _ => 'Step 1 of 3',
              },
              leading: HeaderBackButton(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            ),
            VerificationSteps(
              stepIndex: switch (verification.value) {
                final state? when state.isVerified || state.isAwaitingReview =>
                  2,
                final state? when state.isUnfinished => 1,
                _ => 0,
              },
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: switch (verification) {
                AsyncValue(:final error?) when !verification.hasValue =>
                  _Failed(
                    message: error is ApiException
                        ? error.message
                        : 'Something went wrong. Please try again.',
                    onRetry: () => ref.invalidate(verificationProvider),
                  ),
                AsyncValue(:final value?) => _Body(value),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body(this.verification);

  final Verification verification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(verificationDraftProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 24),
      child: Column(
        children: [
          if (verification.isVerified)
            const _Verified()
          else if (verification.isAwaitingReview)
            _AwaitingReview(verification)
          else ...[
            if (verification.status == VerificationStatus.rejected)
              _Rejected(verification),
            if (verification.isUnfinished)
              _Unfinished(verification)
            else
              _Methods(busy: draft.isBusy),
          ],
          if (draft.error case final message?) ...[
            const SizedBox(height: 16),
            FormErrorBanner(message: message),
          ],
        ],
      ),
    );
  }
}

/// Nothing started yet: pick a way to prove it.
class _Methods extends ConsumerWidget {
  const _Methods({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> start(VerificationMethod method) async {
      final started = await ref
          .read(verificationProvider.notifier)
          .start(method);
      if (started && context.mounted) {
        await context.push<void>(AppRoutes.verificationCapture);
      }
    }

    return Column(
      children: [
        const VerificationBadge(
          asset: AppAssets.shield,
          background: Color(0xFFE0E7FF),
          foreground: Color(0xFF6366F1),
          size: 68,
        ),
        const SizedBox(height: 14),
        const Text(
          'Get verified',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'A moderator checks it by hand, so only you and they ever see what '
          'you send.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 22),
        VerificationMethodCard(
          icon: AppAssets.camera,
          iconBackground: const Color(0xFFE0E7FF),
          iconColor: const Color(0xFF6366F1),
          title: 'Photo verification',
          subtitle: 'Take a selfie. It is checked against your photos.',
          meta: 'Recommended · about 2 minutes',
          onTap: busy ? null : () => unawaited(start(VerificationMethod.photo)),
        ),
        const SizedBox(height: 10),
        VerificationMethodCard(
          icon: AppAssets.upload,
          iconBackground: const Color(0xFFEDE9FE),
          iconColor: AppColors.purple,
          title: 'ID verification',
          subtitle: 'A passport, driving licence or ID card.',
          meta: 'Use this if your photos are hard to match',
          onTap: busy
              ? null
              : () => unawaited(start(VerificationMethod.governmentId)),
        ),
        const SizedBox(height: 16),
        const VerificationTips(
          title: 'What happens to it',
          background: Color(0xFFF1F5F9),
          titleColor: AppColors.textPrimary,
          tips: [
            'It is stored apart from your photos and never appears on your '
                'profile.',
            'Only a Kinvo moderator sees it, to decide yes or no.',
            'Nobody you match with is shown it, ever.',
          ],
        ),
      ],
    );
  }
}

/// Started, not sent: carry on where it stopped.
class _Unfinished extends StatelessWidget {
  const _Unfinished(this.verification);

  final Verification verification;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const VerificationBadge(
          asset: AppAssets.shield,
          background: Color(0xFFE0E7FF),
          foreground: Color(0xFF6366F1),
        ),
        const SizedBox(height: 18),
        const Text(
          'Finish your verification',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          switch (verification.method) {
            VerificationMethod.governmentId =>
              'Your ID has not been sent yet. Pick up where you left off.',
            _ =>
              'Your selfie has not been sent yet. Pick up where you left '
                  'off.',
          },
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        PrimaryActionButton(
          label: 'Continue',
          onPressed: () =>
              unawaited(context.push<void>(AppRoutes.verificationCapture)),
        ),
      ],
    );
  }
}

/// Sent, and with a moderator.
class _AwaitingReview extends ConsumerWidget {
  const _AwaitingReview(this.verification);

  final Verification verification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sentAt = verification.submittedAt;

    return Column(
      children: [
        const VerificationBadge(
          asset: AppAssets.shield,
          background: Color(0xFFE0E7FF),
          foreground: Color(0xFF6366F1),
        ),
        const SizedBox(height: 18),
        const Text(
          'Waiting to be checked',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          sentAt == null
              ? 'A moderator will look at it shortly.'
              : 'Sent ${timeAgo(sentAt, ref.watch(clockProvider)())}. A '
                    'moderator will look at it shortly.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 18),
        const VerificationTips(
          title: 'What happens next',
          background: Color(0xFFF1F5F9),
          titleColor: AppColors.textPrimary,
          tips: [
            'We tell you either way, by notification.',
            'Approved, and the badge appears on your profile straight away.',
            'You can keep using Kinvo while you wait.',
          ],
        ),
        const SizedBox(height: 18),
        OutlineActionButton(
          label: 'Check again',
          onPressed: () =>
              unawaited(ref.read(verificationProvider.notifier).refresh()),
        ),
      ],
    );
  }
}

/// Approved.
class _Verified extends StatelessWidget {
  const _Verified();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const VerificationBadge(
          asset: AppAssets.checkCircle,
          background: Color(0xFFD1FAE5),
          foreground: Color(0xFF10B981),
        ),
        const SizedBox(height: 18),
        const Text(
          "You're verified",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'People see a badge on your profile, and you appear for anyone '
          'looking only for verified people.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        PrimaryActionButton(label: 'Done', onPressed: () => context.pop()),
      ],
    );
  }
}

/// Turned down, with the moderator's reason.
class _Rejected extends StatelessWidget {
  const _Rejected(this.verification);

  final Verification verification;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        children: [
          const VerificationBadge(
            asset: AppAssets.triangleAlert,
            background: Color(0xFFFEE2E2),
            foreground: Color(0xFFB91C1C),
            size: 68,
          ),
          const SizedBox(height: 14),
          const Text(
            'Not approved',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            verification.rejectionReason ??
                'The moderator could not confirm it from what was sent. You '
                    'can try again below.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The check could not be read at all.
class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
