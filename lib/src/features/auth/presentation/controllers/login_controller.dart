import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/forms/form_errors.dart';
import '../../../../core/network/api_error_code.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/email_auth_service.dart';
import '../../domain/account_rules.dart';

/// The fields of the log-in form.
enum LoginField implements ApiFormField {
  email('email'),
  password('password');

  const LoginField(this.wireName);

  @override
  final String wireName;
}

@immutable
final class LoginFormState {
  const LoginFormState({
    this.email = '',
    this.password = '',
    this.rememberDevice = true,
    this.errors = const {},
    this.formError,
    this.hasSubmitted = false,
    this.isSubmitting = false,
  });

  final String email;
  final String password;

  /// Whether to keep the session on this device, so the user is still signed
  /// in after closing the app.
  final bool rememberDevice;

  /// The problem with each field that has one.
  final Map<LoginField, String> errors;

  /// A problem that isn't about one field, such as a wrong password or being
  /// offline.
  final String? formError;

  /// Whether the user has tried to sign in. From then on, fields are checked
  /// as they change, so fixing a mistake clears its error.
  final bool hasSubmitted;

  /// Whether signing in is under way. Stays true once it has worked, while
  /// the app moves on from the form.
  final bool isSubmitting;

  LoginFormState copyWith({
    String? email,
    String? password,
    bool? rememberDevice,
    Map<LoginField, String>? errors,
    ValueGetter<String?>? formError,
    bool? hasSubmitted,
    bool? isSubmitting,
  }) {
    return LoginFormState(
      email: email ?? this.email,
      password: password ?? this.password,
      rememberDevice: rememberDevice ?? this.rememberDevice,
      errors: errors ?? this.errors,
      formError: formError == null ? this.formError : formError(),
      hasSubmitted: hasSubmitted ?? this.hasSubmitted,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

/// The log-in form. Starts empty each time the screen opens.
final loginControllerProvider =
    NotifierProvider.autoDispose<LoginController, LoginFormState>(
      LoginController.new,
    );

class LoginController extends Notifier<LoginFormState> {
  @override
  LoginFormState build() => const LoginFormState();

  void updateEmail(String value) {
    _edit(LoginField.email, state.copyWith(email: value));
  }

  void updatePassword(String value) {
    _edit(LoginField.password, state.copyWith(password: value));
  }

  void setRememberDevice(bool value) {
    state = state.copyWith(rememberDevice: value);
  }

  /// Signs in.
  ///
  /// Returns whether that worked. If it didn't, the form explains why, under
  /// the fields at fault or in [LoginFormState.formError].
  Future<bool> submit() async {
    if (state.isSubmitting) return false;

    final errors = _check(state);
    if (errors.isNotEmpty) {
      state = state.copyWith(
        errors: errors,
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
      await ref
          .read(emailAuthServiceProvider)
          .login(
            email: form.email,
            password: form.password,
            remember: form.rememberDevice,
          );
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

  LoginFormState _failed(ApiException error) {
    final form = state.copyWith(isSubmitting: false);
    switch (error) {
      case ApiErrorException(code: ApiErrorCode.validationFailed):
        final sorted = sortFieldErrors(error, LoginField.values);
        return form.copyWith(
          errors: sorted.fieldErrors,
          formError: () => sorted.formError,
        );
      // Wrong details, a suspended account and too many attempts are all
      // explained by the server's message. It never says which detail was
      // wrong, so neither does the form.
      case ApiException():
        return form.copyWith(formError: () => error.message);
    }
  }

  /// Applies an edit to [field]. Any error it had was about the old value;
  /// once the user has tried to submit, the new value is checked instead.
  void _edit(LoginField field, LoginFormState edited) {
    final errors = {...edited.errors}..remove(field);
    if (edited.hasSubmitted) {
      if (_checkField(field, edited) case final error?) errors[field] = error;
    }
    state = edited.copyWith(errors: errors, formError: () => null);
  }

  Map<LoginField, String> _check(LoginFormState form) {
    return {
      for (final field in LoginField.values) field: ?_checkField(field, form),
    };
  }

  String? _checkField(LoginField field, LoginFormState form) {
    return switch (field) {
      LoginField.email => AccountRules.emailError(form.email),
      LoginField.password => AccountRules.passwordError(form.password),
    };
  }
}
