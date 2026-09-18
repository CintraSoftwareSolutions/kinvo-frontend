import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/forms/form_errors.dart';
import '../../../../core/network/api_error_code.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/time/calendar_date.dart';
import '../../../../core/time/clock.dart';
import '../../../auth/domain/account_rules.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../profile/domain/profile_fields.dart';
import '../../../profile/domain/profile_rules.dart';
import '../../data/onboarding_repository.dart';
import 'onboarding_controller.dart';

/// The fields of the "About you" step.
enum AboutField implements ApiFormField {
  displayName('display_name'),
  bio('bio'),
  dateOfBirth('date_of_birth');

  const AboutField(this.wireName);

  @override
  final String wireName;
}

@immutable
final class AboutFormState {
  const AboutFormState({
    required this.displayName,
    required this.bio,
    required this.bioMaxLength,
    required this.needsDateOfBirth,
    this.dateOfBirth,
    this.errors = const {},
    this.formError,
    this.hasSubmitted = false,
    this.isSubmitting = false,
  });

  final String displayName;
  final String bio;
  final int bioMaxLength;

  /// Whether the form asks for a date of birth. Accounts made by email already
  /// have one.
  final bool needsDateOfBirth;
  final CalendarDate? dateOfBirth;

  final Map<AboutField, String> errors;
  final String? formError;
  final bool hasSubmitted;
  final bool isSubmitting;

  AboutFormState copyWith({
    String? displayName,
    String? bio,
    CalendarDate? dateOfBirth,
    Map<AboutField, String>? errors,
    ValueGetter<String?>? formError,
    bool? hasSubmitted,
    bool? isSubmitting,
  }) {
    return AboutFormState(
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      bioMaxLength: bioMaxLength,
      needsDateOfBirth: needsDateOfBirth,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      errors: errors ?? this.errors,
      formError: formError == null ? this.formError : formError(),
      hasSubmitted: hasSubmitted ?? this.hasSubmitted,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

final aboutStepControllerProvider =
    NotifierProvider.autoDispose<AboutStepController, AboutFormState>(
      AboutStepController.new,
    );

class AboutStepController extends Notifier<AboutFormState> {
  @override
  AboutFormState build() {
    // Read once: from here on the form holds what the user types.
    final onboarding = ref.read(onboardingControllerProvider).requireValue;
    return AboutFormState(
      displayName: onboarding.profile.displayName,
      bio: onboarding.profile.bio ?? '',
      bioMaxLength: onboarding.config.limits.bioMaxLength,
      needsDateOfBirth: onboarding.needsDateOfBirth,
      dateOfBirth: onboarding.profile.dateOfBirth,
    );
  }

  void updateDisplayName(String value) {
    _edit(AboutField.displayName, state.copyWith(displayName: value));
  }

  void updateBio(String value) {
    _edit(AboutField.bio, state.copyWith(bio: value));
  }

  void updateDateOfBirth(CalendarDate value) {
    _edit(AboutField.dateOfBirth, state.copyWith(dateOfBirth: value));
  }

  /// Saves what changed and moves on to the next step. Returns whether that
  /// worked; if not, the form explains why.
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
    final flow = ref.read(onboardingControllerProvider.notifier);
    final saved = ref.read(onboardingControllerProvider).requireValue.profile;

    try {
      final displayName = form.displayName.trim();
      final bio = form.bio.trim();
      final nameChanged = displayName != saved.displayName;
      final bioChanged = bio != (saved.bio ?? '');
      if (nameChanged || bioChanged) {
        final profile = await ref
            .read(profileRepositoryProvider)
            .updateDetails({
              if (nameChanged) ProfileField.displayName: displayName,
              if (bioChanged) ProfileField.bio: bio,
            });
        // Recorded straight away, so a failure below doesn't save it twice.
        flow.profileSaved(profile);
      }

      if (form.dateOfBirth case final dateOfBirth? when form.needsDateOfBirth) {
        await _saveDateOfBirth(dateOfBirth);
        flow.dateOfBirthSaved();
      }

      flow.next();
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

  Future<void> _saveDateOfBirth(CalendarDate dateOfBirth) async {
    try {
      await ref.read(onboardingRepositoryProvider).setDateOfBirth(dateOfBirth);
    } on ApiErrorException catch (error) {
      // A conflict means it's already set, for example by an attempt whose
      // response was lost.
      if (error.code != ApiErrorCode.conflict) rethrow;
    }
  }

  AboutFormState _failed(ApiException error) {
    final form = state.copyWith(isSubmitting: false);
    switch (error) {
      case ApiErrorException(code: ApiErrorCode.validationFailed):
        final sorted = sortFieldErrors(error, AboutField.values);
        return form.copyWith(
          errors: sorted.fieldErrors,
          formError: () => sorted.formError,
        );
      case ApiException():
        return form.copyWith(formError: () => error.message);
    }
  }

  /// Applies an edit to [field]. Any error it had was about the old value;
  /// once the user has tried to continue, the new value is checked instead.
  void _edit(AboutField field, AboutFormState edited) {
    final errors = {...edited.errors}..remove(field);
    if (edited.hasSubmitted) {
      if (_checkField(field, edited) case final error?) errors[field] = error;
    }
    state = edited.copyWith(errors: errors, formError: () => null);
  }

  Map<AboutField, String> _check(AboutFormState form) {
    return {
      for (final field in AboutField.values) field: ?_checkField(field, form),
    };
  }

  String? _checkField(AboutField field, AboutFormState form) {
    return switch (field) {
      AboutField.displayName => AccountRules.displayNameError(form.displayName),
      AboutField.bio => ProfileRules.bioError(
        form.bio,
        maxLength: form.bioMaxLength,
      ),
      AboutField.dateOfBirth =>
        form.needsDateOfBirth
            ? AccountRules.dateOfBirthError(
                form.dateOfBirth,
                today: CalendarDate.fromDateTime(ref.read(clockProvider)()),
              )
            : null,
    };
  }
}
