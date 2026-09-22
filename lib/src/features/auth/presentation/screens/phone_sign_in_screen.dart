import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/widgets/flow_widgets.dart';
import '../../../../core/widgets/gradient_scaffold.dart';
import '../controllers/phone_sign_in_controller.dart';

/// Signing in with a phone number: the number, then the code texted to it.
///
/// One screen for both steps. They are one thought — "prove this is my
/// number" — and a second screen would mean a back button that throws away
/// the number just typed.
class PhoneSignInScreen extends ConsumerStatefulWidget {
  const PhoneSignInScreen({super.key});

  @override
  ConsumerState<PhoneSignInScreen> createState() => _PhoneSignInScreenState();
}

class _PhoneSignInScreenState extends ConsumerState<PhoneSignInScreen> {
  Timer? _countdown;

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  /// Redraws the "Send again in 12s" line once a second, and stops itself the
  /// moment there is nothing left to count, so a screen sitting on the number
  /// step is not rebuilding every second for nothing.
  void _startCountdown() {
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final form = ref.read(phoneSignInControllerProvider);
      final now = ref.read(clockProvider)();
      if (form.remainingBeforeResend(now) == Duration.zero) timer.cancel();
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(phoneSignInControllerProvider);
    final onCode = form.step == PhoneStep.code;

    return GradientScaffold(
      background: AppColors.lightBackground,
      child: FlowPageLayout(
        badgeText: 'Phone sign-in',
        badgeIcon: Icons.smartphone_rounded,
        title: onCode ? 'Enter the code' : 'Sign in with your phone',
        subtitle: onCode
            ? 'We texted a code to ${form.phone}. It is good for a few minutes.'
            : 'We will text you a code. No password to remember.',
        content: SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: onCode ? _codeStep(form) : _numberStep(form),
          ),
        ),
      ),
    );
  }

  List<Widget> _numberStep(PhoneSignInState form) {
    final controller = ref.read(phoneSignInControllerProvider.notifier);

    return [
      AppInputCard(
        label: 'PHONE NUMBER',
        value: form.phone,
        assetName: AppAssets.smartphone,
        keyboardType: TextInputType.phone,
        enabled: !form.isSubmitting,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: const [AutofillHints.telephoneNumber],
        textInputAction: TextInputAction.done,
        onChanged: controller.updatePhone,
        onSubmitted: (_) => unawaited(_send()),
        hintText: '+44 7700 900123',
      ),
      const SizedBox(height: 8),
      const Text(
        'Start with your country code, like +44 or +92.',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      if (form.error case final message?) ...[
        const SizedBox(height: 14),
        FormErrorBanner(message: message),
      ],
      const SizedBox(height: 16),
      PrimaryActionButton(
        label: 'Send code',
        loading: form.isSubmitting,
        onPressed: form.canSend ? () => unawaited(_send()) : null,
      ),
      const SizedBox(height: 10),
      Center(
        child: TextButton(
          onPressed: form.isSubmitting ? null : _leave,
          child: const Text(
            'Use an email address instead',
            style: TextStyle(fontSize: 13),
          ),
        ),
      ),
    ];
  }

  List<Widget> _codeStep(PhoneSignInState form) {
    final controller = ref.read(phoneSignInControllerProvider.notifier);
    final waiting = form.remainingBeforeResend(ref.watch(clockProvider)());

    return [
      AppInputCard(
        label: 'CODE',
        value: form.code,
        assetName: AppAssets.lock,
        keyboardType: TextInputType.number,
        enabled: !form.isSubmitting,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: const [AutofillHints.oneTimeCode],
        textInputAction: TextInputAction.done,
        onChanged: controller.updateCode,
        onSubmitted: (_) => unawaited(_verify()),
        hintText: '123456',
      ),
      if (form.error case final message?) ...[
        const SizedBox(height: 14),
        FormErrorBanner(message: message),
      ],
      const SizedBox(height: 16),
      PrimaryActionButton(
        label: 'Continue',
        loading: form.isSubmitting,
        onPressed: form.canVerify ? () => unawaited(_verify()) : null,
      ),
      const SizedBox(height: 6),
      Center(
        child: TextButton(
          onPressed: waiting == Duration.zero && !form.isSubmitting
              ? () => unawaited(_send())
              : null,
          child: Text(
            waiting == Duration.zero
                ? 'Send the code again'
                : 'Send again in ${waiting.inSeconds}s',
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ),
      Center(
        child: TextButton(
          onPressed: form.isSubmitting ? null : controller.editNumber,
          child: const Text(
            'Use a different number',
            style: TextStyle(fontSize: 13),
          ),
        ),
      ),
    ];
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    final sent = await ref
        .read(phoneSignInControllerProvider.notifier)
        .sendCode();
    if (sent && mounted) _startCountdown();
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    // Whatever comes back, nothing is pushed here: a session starting moves
    // the router on its own, and a new account lands in onboarding, where the
    // first question is the date of birth it does not have yet.
    await ref.read(phoneSignInControllerProvider.notifier).verify();
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.login);
    }
  }
}
