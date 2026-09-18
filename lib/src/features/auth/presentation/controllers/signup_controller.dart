import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/forms/form_errors.dart';
import '../../../../core/network/api_error_code.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/time/calendar_date.dart';
import '../../../../core/time/clock.dart';
import '../../data/email_auth_service.dart';
import '../../domain/account_rules.dart';

/// The fields of the sign-up form.
enum SignupField implements ApiFormField {
  displayName('display_name'),
  email('email'),
  password('password'),
  dateOfBirth('date_of_birth');

  const SignupField(this.wireName);

  @override
  final String wireName;
}

@immutable
final class SignupFormState {
  const SignupFormState({
    this.displayName = '',
    this.email = '',
    this.password = '',
    this.dateOfBirth,
    this.errors = const {},
    this.formError,
    this.hasSubmitted = false,
    this.isSubmitting = false,
  });

  final String displayName;
  final String email;
  final String password;
  final CalendarDate? dateOfBirth;

  /// The problem with each field that has one.
  final Map<SignupField, String> errors;

  /// A problem that isn't about one field, such as being offline.
  final String? formError;

  /// Whether the user has tried to create the account. From then on, fields
  /// are checked as they change, so fixing a mistake clears its error.
  final bool hasSubmitted;

  /// Whether the account is being created. Stays true once it has been,
  /// while the app moves on from the form.
  final bool isSubmitting;

  SignupFormState copyWith({
    String? displayName,
    String? email,
    String? password,
    CalendarDate? dateOfBirth,
    Map<SignupField, String>? errors,
    ValueGetter<String?>? formError,
    bool? hasSubmitted,
    bool? isSubmitting,
  }) {
    return SignupFormState(
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      password: password ?? this.password,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      errors: errors ?? this.errors,
      formError: formError == null ? this.formError : formError(),
      hasSubmitted: hasSubmitted ?? this.hasSubmitted,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

/// The sign-up form. Starts empty each time the screen opens.
final signupControllerProvider =
    NotifierProvider.autoDispose<SignupController, SignupFormState>(
      SignupController.new,
    );

class SignupController extends Notifier<SignupFormState> {
  @override
  SignupFormState build() => const SignupFormState();

  void updateDisplayName(String value) {
    _edit(SignupField.displayName, state.copyWith(displayName: value));
  }

  void updateEmail(String value) {
    _edit(SignupField.email, state.copyWith(email: value));
  }

  void updatePassword(String value) {
    _edit(SignupField.password, state.copyWith(password: value));
  }

  void updateDateOfBirth(CalendarDate value) {
    _edit(SignupField.dateOfBirth, state.copyWith(dateOfBirth: value));
  }

  /// Creates the account and signs in to it.
  ///
  /// Returns whether that worked. If it didn't, the form explains why, under
  /// the fields at fault or in [SignupFormState.formError].
  Future<bool> submit() async {
    if (state.isSubmitting) return false;

    final errors = _check(state);
    final dateOfBirth = state.dateOfBirth;
    if (errors.isNotEmpty || dateOfBirth == null) {
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
          .register(
            displayName: form.displayName,
            email: form.email,
            password: form.password,
            dateOfBirth: dateOfBirth,
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

  SignupFormState _failed(ApiException error) {
    final form = state.copyWith(isSubmitting: false);
    switch (error) {
      case ApiErrorException(code: ApiErrorCode.validationFailed):
        final sorted = sortFieldErrors(error, SignupField.values);
        return form.copyWith(
          errors: sorted.fieldErrors,
          formError: () => sorted.formError,
        );
      case ApiErrorException(code: ApiErrorCode.conflict):
        // The only conflict registering can hit: the email is already in use.
        return form.copyWith(errors: {SignupField.email: error.message});
      case ApiException():
        return form.copyWith(formError: () => error.message);
    }
  }

  /// Applies an edit to [field]. Any error it had was about the old value;
  /// once the user has tried to submit, the new value is checked instead.
  void _edit(SignupField field, SignupFormState edited) {
    final errors = {...edited.errors}..remove(field);
    if (edited.hasSubmitted) {
      if (_checkField(field, edited) case final error?) errors[field] = error;
    }
    state = edited.copyWith(errors: errors, formError: () => null);
  }

  Map<SignupField, String> _check(SignupFormState form) {
    return {
      for (final field in SignupField.values) field: ?_checkField(field, form),
    };
  }

  String? _checkField(SignupField field, SignupFormState form) {
    return switch (field) {
      SignupField.displayName => AccountRules.displayNameError(
        form.displayName,
      ),
      SignupField.email => AccountRules.emailError(form.email),
      SignupField.password => AccountRules.newPasswordError(form.password),
      SignupField.dateOfBirth => AccountRules.dateOfBirthError(
        form.dateOfBirth,
        today: CalendarDate.fromDateTime(ref.read(clockProvider)()),
      ),
    };
  }
}
