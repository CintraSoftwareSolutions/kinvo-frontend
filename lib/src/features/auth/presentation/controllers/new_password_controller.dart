import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/forms/form_errors.dart';
import '../../../../core/network/api_error_code.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/time/clock.dart';
import '../../data/password_reset_service.dart';
import '../../domain/account_rules.dart';
import 'password_reset_controller.dart';

/// The fields of the "choose a new password" form.
enum NewPasswordField implements ApiFormField {
  code('code'),
  password('password');

  const NewPasswordField(this.wireName);

  @override
  final String wireName;
}

@immutable
final class NewPasswordFormState {
  const NewPasswordFormState({
    this.code = '',
    this.password = '',
    this.errors = const {},
    this.formError,
    this.notice,
    this.hasSubmitted = false,
    this.isSubmitting = false,
    this.isResending = false,
  });

  final String code;
  final String password;
  final Map<NewPasswordField, String> errors;

  /// A problem that isn't about one field, such as being offline.
  final String? formError;

  /// Something that went right and the user can't otherwise see, such as a new
  /// code being on its way.
  final String? notice;

  final bool hasSubmitted;
  final bool isSubmitting;
  final bool isResending;

  /// Whether anything can be typed or tapped.
  bool get isBusy => isSubmitting || isResending;

  NewPasswordFormState copyWith({
    String? code,
    String? password,
    Map<NewPasswordField, String>? errors,
    ValueGetter<String?>? formError,
    ValueGetter<String?>? notice,
    bool? hasSubmitted,
    bool? isSubmitting,
    bool? isResending,
  }) {
    return NewPasswordFormState(
      code: code ?? this.code,
      password: password ?? this.password,
      errors: errors ?? this.errors,
      formError: formError == null ? this.formError : formError(),
      notice: notice == null ? this.notice : notice(),
      hasSubmitted: hasSubmitted ?? this.hasSubmitted,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isResending: isResending ?? this.isResending,
    );
  }
}

/// The second step of a password reset: the code from the email, and the
/// password to replace the forgotten one.
final newPasswordControllerProvider =
    NotifierProvider.autoDispose<NewPasswordController, NewPasswordFormState>(
      NewPasswordController.new,
    );

class NewPasswordController extends Notifier<NewPasswordFormState> {
  @override
  NewPasswordFormState build() => const NewPasswordFormState();

  void updateCode(String value) {
    _edit(NewPasswordField.code, state.copyWith(code: value));
  }

  void updatePassword(String value) {
    _edit(NewPasswordField.password, state.copyWith(password: value));
  }

  /// Sets the new password.
  ///
  /// Returns how it left the user — signed in, or with a password they now
  /// have to sign in with — or null if it didn't work, in which case the form
  /// says why.
  Future<PasswordResetOutcome?> submit() async {
    final pending = ref.read(pendingPasswordResetProvider);
    if (pending == null || state.isBusy) return null;

    final errors = _check(state);
    if (errors.isNotEmpty) {
      state = state.copyWith(
        errors: errors,
        formError: () => null,
        notice: () => null,
        hasSubmitted: true,
      );
      return null;
    }

    final form = state.copyWith(
      errors: const {},
      formError: () => null,
      notice: () => null,
      hasSubmitted: true,
      isSubmitting: true,
    );
    state = form;

    try {
      final outcome = await ref
          .read(passwordResetServiceProvider)
          .confirm(
            email: pending.email,
            code: form.code.trim(),
            password: form.password,
          );

      // The code is spent either way, so the flow is over even when the
      // sign-in afterwards didn't work.
      ref.read(pendingPasswordResetProvider.notifier).cleared();
      return outcome;
    } on ApiException catch (error) {
      if (ref.mounted) state = _failed(error);
      return null;
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

  /// Sends another code to the same address.
  ///
  /// The server allows five an hour per address, and every new code retires
  /// the last one, so this refuses to spend them faster than
  /// [resendCodeCooldown].
  Future<void> resend() async {
    final pending = ref.read(pendingPasswordResetProvider);
    if (pending == null || state.isBusy) return;

    final waited = ref.read(clockProvider)().difference(pending.sentAt);
    if (waited < resendCodeCooldown) {
      state = state.copyWith(
        notice: () => null,
        formError: () =>
            'Check your inbox first. You can ask for another code in a moment.',
      );
      return;
    }

    state = state.copyWith(
      isResending: true,
      formError: () => null,
      notice: () => null,
    );

    try {
      await ref
          .read(passwordResetServiceProvider)
          .sendCode(email: pending.email);

      ref
          .read(pendingPasswordResetProvider.notifier)
          .started(
            PendingPasswordReset(
              email: pending.email,
              sentAt: ref.read(clockProvider)(),
            ),
          );

      if (!ref.mounted) return;
      // The code that was typed is retired now, so it goes with it.
      state = state.copyWith(
        code: '',
        errors: {...state.errors}..remove(NewPasswordField.code),
        isResending: false,
        notice: () => 'A new code is on its way.',
      );
    } on ApiException catch (error) {
      if (ref.mounted) {
        state = state.copyWith(
          isResending: false,
          formError: () => error.message,
        );
      }
    } on Object {
      if (ref.mounted) {
        state = state.copyWith(
          isResending: false,
          formError: () => unexpectedFailureMessage,
        );
      }
      rethrow;
    }
  }

  NewPasswordFormState _failed(ApiException error) {
    final form = state.copyWith(isSubmitting: false);
    switch (error) {
      case ApiErrorException(code: ApiErrorCode.validationFailed):
        final sorted = sortFieldErrors(error, NewPasswordField.values);
        return form.copyWith(
          errors: sorted.fieldErrors,
          formError: () => sorted.formError,
        );
      // Wrong, expired, already used, or out of guesses: the server tells them
      // apart for nobody, and the only thing to do about any of them is to
      // check the code or ask for another.
      case ApiErrorException(code: ApiErrorCode.authTokenInvalid):
        return form.copyWith(errors: {NewPasswordField.code: error.message});
      case ApiException():
        return form.copyWith(formError: () => error.message);
    }
  }

  /// Applies an edit to [field]. Any error it had was about the old value;
  /// once the user has tried to submit, the new value is checked instead.
  void _edit(NewPasswordField field, NewPasswordFormState edited) {
    final errors = {...edited.errors}..remove(field);
    if (edited.hasSubmitted) {
      if (_checkField(field, edited) case final error?) errors[field] = error;
    }
    state = edited.copyWith(
      errors: errors,
      formError: () => null,
      notice: () => null,
    );
  }

  Map<NewPasswordField, String> _check(NewPasswordFormState form) {
    return {
      for (final field in NewPasswordField.values)
        field: ?_checkField(field, form),
    };
  }

  String? _checkField(NewPasswordField field, NewPasswordFormState form) {
    return switch (field) {
      NewPasswordField.code => AccountRules.resetCodeError(form.code),
      NewPasswordField.password => AccountRules.newPasswordError(form.password),
    };
  }
}
