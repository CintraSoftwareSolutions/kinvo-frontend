import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/forms/form_errors.dart';
import '../../../../core/network/api_error_code.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/time/clock.dart';
import '../../data/password_reset_service.dart';
import '../../domain/account_rules.dart';
import 'login_controller.dart';

/// A reset code that has been asked for and not yet used.
///
/// Held outside both screens so the flow survives moving between them, and
/// cleared as soon as the code is spent.
@immutable
final class PendingPasswordReset {
  const PendingPasswordReset({required this.email, required this.sentAt});

  /// The address the code was sent to, already trimmed.
  final String email;

  /// When it was sent, so the app doesn't spend the account's small hourly
  /// allowance of codes on impatient taps.
  final DateTime sentAt;
}

/// How long to wait before asking for another code. The server allows five an
/// hour per address, so nothing here should burn through them.
const resendCodeCooldown = Duration(seconds: 60);

final pendingPasswordResetProvider =
    NotifierProvider<PendingPasswordResetController, PendingPasswordReset?>(
      PendingPasswordResetController.new,
    );

class PendingPasswordResetController extends Notifier<PendingPasswordReset?> {
  @override
  PendingPasswordReset? build() => null;

  void started(PendingPasswordReset request) => state = request;

  /// The code has been used, or the user has left the flow.
  void cleared() => state = null;
}

/// The one field of the "send me a code" form.
enum ResetRequestField implements ApiFormField {
  email('email');

  const ResetRequestField(this.wireName);

  @override
  final String wireName;
}

@immutable
final class ResetRequestFormState {
  const ResetRequestFormState({
    this.email = '',
    this.errors = const {},
    this.formError,
    this.hasSubmitted = false,
    this.isSubmitting = false,
  });

  final String email;
  final Map<ResetRequestField, String> errors;

  /// A problem that isn't about the field, such as being offline or asking too
  /// often.
  final String? formError;

  /// Whether the user has tried to send. From then on the address is checked
  /// as it changes, so fixing a mistake clears its error.
  final bool hasSubmitted;
  final bool isSubmitting;

  ResetRequestFormState copyWith({
    String? email,
    Map<ResetRequestField, String>? errors,
    ValueGetter<String?>? formError,
    bool? hasSubmitted,
    bool? isSubmitting,
  }) {
    return ResetRequestFormState(
      email: email ?? this.email,
      errors: errors ?? this.errors,
      formError: formError == null ? this.formError : formError(),
      hasSubmitted: hasSubmitted ?? this.hasSubmitted,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

/// The first step of a password reset: which address to send the code to.
final resetRequestControllerProvider =
    NotifierProvider.autoDispose<ResetRequestController, ResetRequestFormState>(
      ResetRequestController.new,
    );

class ResetRequestController extends Notifier<ResetRequestFormState> {
  @override
  ResetRequestFormState build() {
    // Carried over from the log-in screen, the only way here, so the address
    // isn't typed twice. Read rather than watched: it is a starting value, not
    // something this form follows.
    return ResetRequestFormState(
      email: ref.read(loginControllerProvider).email,
    );
  }

  void updateEmail(String value) {
    final edited = state.copyWith(email: value);
    final errors = {...edited.errors}..remove(ResetRequestField.email);
    if (edited.hasSubmitted) {
      if (AccountRules.emailError(edited.email) case final error?) {
        errors[ResetRequestField.email] = error;
      }
    }
    state = edited.copyWith(errors: errors, formError: () => null);
  }

  /// Asks the server to email a code.
  ///
  /// Returns whether to move on to the next step. Success says nothing about
  /// whether the address has an account — the server answers the same either
  /// way — so the next screen asks for a code without promising one is coming.
  Future<bool> submit() async {
    if (state.isSubmitting) return false;

    if (AccountRules.emailError(state.email) case final error?) {
      state = state.copyWith(
        errors: {ResetRequestField.email: error},
        formError: () => null,
        hasSubmitted: true,
      );
      return false;
    }

    final form = state.copyWith(
      errors: const {},
      formError: () => null,
      hasSubmitted: true,
      isSubmitting: true,
    );
    state = form;

    try {
      await ref.read(passwordResetServiceProvider).sendCode(email: form.email);

      ref
          .read(pendingPasswordResetProvider.notifier)
          .started(
            PendingPasswordReset(
              email: form.email.trim(),
              sentAt: ref.read(clockProvider)(),
            ),
          );

      if (ref.mounted) state = state.copyWith(isSubmitting: false);
      return true;
    } on ApiException catch (error) {
      if (ref.mounted) state = _failed(error);
      return false;
    } on Object {
      if (ref.mounted) {
        state = state.copyWith(
          isSubmitting: false,
          formError: () => unexpectedFailureMessage,
        );
      }
      rethrow;
    }
  }

  ResetRequestFormState _failed(ApiException error) {
    final form = state.copyWith(isSubmitting: false);
    switch (error) {
      case ApiErrorException(code: ApiErrorCode.validationFailed):
        final sorted = sortFieldErrors(error, ResetRequestField.values);
        return form.copyWith(
          errors: sorted.fieldErrors,
          formError: () => sorted.formError,
        );
      case ApiException():
        return form.copyWith(formError: () => error.message);
    }
  }
}
