import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/forms/form_errors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/time/clock.dart';
import '../../data/phone_auth_service.dart';

/// How long before another code can be asked for.
///
/// The server rate-limits this as well; the countdown exists so the button
/// says when it will work again rather than failing when it is pressed. Long
/// enough that a slow SMS is not chased by a second one, which is how people
/// end up entering the older of two codes.
const resendCodeAfter = Duration(seconds: 30);

/// Which half of signing in with a phone number is on screen.
enum PhoneStep { number, code }

@immutable
final class PhoneSignInState {
  const PhoneSignInState({
    this.step = PhoneStep.number,
    this.phone = '',
    this.code = '',
    this.error,
    this.isSubmitting = false,
    this.codeSentAt,
  });

  final PhoneStep step;
  final String phone;
  final String code;

  /// What went wrong, in words, or null.
  final String? error;

  final bool isSubmitting;

  /// When the last code was sent, for the resend countdown.
  final DateTime? codeSentAt;

  /// Whether the number could be accepted, checked before sending so a typo
  /// costs nobody an SMS.
  bool get canSend => PhoneAuthService.looksValid(phone) && !isSubmitting;

  /// Twilio's codes are six digits.
  bool get canVerify => code.trim().length >= 4 && !isSubmitting;

  /// How long until another code can be asked for.
  Duration remainingBeforeResend(DateTime now) {
    final sentAt = codeSentAt;
    if (sentAt == null) return Duration.zero;

    final waited = now.difference(sentAt);
    final left = resendCodeAfter - waited;
    return left.isNegative ? Duration.zero : left;
  }

  PhoneSignInState copyWith({
    PhoneStep? step,
    String? phone,
    String? code,
    ValueGetter<String?>? error,
    bool? isSubmitting,
    ValueGetter<DateTime?>? codeSentAt,
  }) {
    return PhoneSignInState(
      step: step ?? this.step,
      phone: phone ?? this.phone,
      code: code ?? this.code,
      error: error == null ? this.error : error(),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      codeSentAt: codeSentAt == null ? this.codeSentAt : codeSentAt(),
    );
  }
}

/// Signing in with a phone number: ask for the number, then the code.
///
/// One controller for both steps, because they are one flow — going back to
/// change a mistyped number must keep everything else, and a second controller
/// would mean two places holding the number.
final phoneSignInControllerProvider =
    NotifierProvider.autoDispose<PhoneSignInController, PhoneSignInState>(
      PhoneSignInController.new,
    );

class PhoneSignInController extends Notifier<PhoneSignInState> {
  @override
  PhoneSignInState build() => const PhoneSignInState();

  PhoneAuthService get _service => ref.read(phoneAuthServiceProvider);

  void updatePhone(String value) {
    state = state.copyWith(phone: value, error: () => null);
  }

  void updateCode(String value) {
    state = state.copyWith(code: value, error: () => null);
  }

  /// Back to the number, keeping it, so a wrong digit is a two-second fix.
  void editNumber() {
    state = state.copyWith(step: PhoneStep.number, code: '', error: () => null);
  }

  /// Sends a code and moves to the code step. Returns whether it went.
  Future<bool> sendCode() async {
    if (state.isSubmitting) return false;

    if (!PhoneAuthService.looksValid(state.phone)) {
      state = state.copyWith(
        error: () =>
            'Enter your number with its country code, like +44 7700 900123.',
      );
      return false;
    }

    state = state.copyWith(isSubmitting: true, error: () => null);

    try {
      await _service.sendCode(state.phone);

      if (!ref.mounted) return true;
      state = state.copyWith(
        step: PhoneStep.code,
        isSubmitting: false,
        codeSentAt: () => ref.read(clockProvider)(),
      );
      return true;
    } on ApiException catch (error) {
      if (ref.mounted) state = _failed(error);
      return false;
    }
  }

  /// Verifies the code. Returns true when signed in, and whether the account
  /// was created just now is what the screen uses to decide where to go.
  Future<PhoneSignInOutcome> verify() async {
    if (state.isSubmitting) return PhoneSignInOutcome.notTried;

    state = state.copyWith(isSubmitting: true, error: () => null);

    try {
      final isNew = await _service.signIn(phone: state.phone, code: state.code);
      // No state change on success: the session has started, the router is
      // already moving, and touching state now would rebuild a screen that is
      // on its way out.
      return isNew
          ? PhoneSignInOutcome.newAccount
          : PhoneSignInOutcome.signedIn;
    } on ApiException catch (error) {
      if (ref.mounted) state = _failed(error);
      return PhoneSignInOutcome.failed;
    }
  }

  /// The server's own words, which are written to be shown.
  ///
  /// It says the same thing for a wrong code and an expired one, on purpose:
  /// telling them apart tells someone guessing which half they got right. A
  /// number Twilio cannot text comes back as an error on the field itself,
  /// which says far more than "some fields need attention".
  PhoneSignInState _failed(ApiException error) {
    final field = state.step == PhoneStep.number ? 'phone' : 'code';

    return state.copyWith(
      isSubmitting: false,
      error: () => saveFailureMessage(error, field: field),
    );
  }
}

/// What came of verifying a code.
enum PhoneSignInOutcome {
  /// Signed in to an account that already existed.
  signedIn,

  /// Signed in to an account created just now, which has no name or date of
  /// birth yet.
  newAccount,

  failed,
  notTried,
}
