import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/forms/form_errors.dart';
import '../../../../core/network/api_error_code.dart';
import '../../../../core/network/api_exception.dart';
import '../../../profile/data/profile_repository.dart';
import 'onboarding_controller.dart';

@immutable
final class InterestsFormState {
  const InterestsFormState({
    required this.selected,
    required this.maxInterests,
    this.error,
    this.isSubmitting = false,
  });

  /// Interest slugs, in the order they were chosen.
  final List<String> selected;
  final int maxInterests;
  final String? error;
  final bool isSubmitting;

  bool get isFull => selected.length >= maxInterests;

  InterestsFormState copyWith({
    List<String>? selected,
    ValueGetter<String?>? error,
    bool? isSubmitting,
  }) {
    return InterestsFormState(
      selected: selected ?? this.selected,
      maxInterests: maxInterests,
      error: error == null ? this.error : error(),
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

final interestsStepControllerProvider =
    NotifierProvider.autoDispose<InterestsStepController, InterestsFormState>(
      InterestsStepController.new,
    );

class InterestsStepController extends Notifier<InterestsFormState> {
  static const noneChosenMessage = 'Choose at least one interest.';

  @override
  InterestsFormState build() {
    final onboarding = ref.read(onboardingControllerProvider).requireValue;
    final offered = {
      for (final interest in onboarding.config.interests) interest.slug,
    };
    return InterestsFormState(
      // An interest the server no longer offers can't be saved again.
      selected: [
        for (final slug in onboarding.profile.interestSlugs)
          if (offered.contains(slug)) slug,
      ],
      maxInterests: onboarding.config.limits.maxInterests,
    );
  }

  void toggle(String slug) {
    if (state.isSubmitting) return;
    if (state.selected.contains(slug)) {
      state = state.copyWith(
        selected: [...state.selected]..remove(slug),
        error: () => null,
      );
    } else if (state.isFull) {
      state = state.copyWith(
        error: () => 'You can choose up to ${state.maxInterests} interests.',
      );
    } else {
      state = state.copyWith(
        selected: [...state.selected, slug],
        error: () => null,
      );
    }
  }

  /// Saves the interests if they changed, then moves on. Returns whether that
  /// worked; if not, the form explains why.
  Future<bool> submit() async {
    if (state.isSubmitting) return false;
    if (state.selected.isEmpty) {
      state = state.copyWith(error: () => noneChosenMessage);
      return false;
    }

    final form = state.copyWith(isSubmitting: true, error: () => null);
    state = form;
    final flow = ref.read(onboardingControllerProvider.notifier);
    final saved = ref.read(onboardingControllerProvider).requireValue.profile;

    try {
      if (!setEquals(form.selected.toSet(), saved.interestSlugs.toSet())) {
        flow.profileSaved(
          await ref.read(profileRepositoryProvider).setInterests(form.selected),
        );
      }
      flow.next();
      return true;
    } on ApiException catch (error) {
      if (ref.mounted) {
        state = state.copyWith(
          isSubmitting: false,
          error: () => _messageFor(error),
        );
      }
      return false;
    } on Object {
      if (ref.mounted) {
        state = state.copyWith(
          isSubmitting: false,
          error: () => unexpectedFailureMessage,
        );
      }
      rethrow;
    }
  }

  static String _messageFor(ApiException error) {
    return switch (error) {
      // The form is a single list, so its first problem is the one to show.
      ApiErrorException(code: ApiErrorCode.validationFailed) =>
        error.fieldErrors.values.expand((messages) => messages).firstOrNull ??
            error.message,
      _ => error.message,
    };
  }
}
