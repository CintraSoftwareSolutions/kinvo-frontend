import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/forms/form_errors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../modes/data/modes_repository.dart';
import '../../../modes/domain/user_modes.dart';
import 'onboarding_controller.dart';

@immutable
final class ModesFormState {
  const ModesFormState({
    required this.selected,
    required this.maxEnabled,
    this.error,
    this.isSubmitting = false,
  });

  /// Mode names in the order they were chosen. The first is the main mode.
  final List<String> selected;

  /// How many modes the user's plan allows at once, or `null` for no limit.
  final int? maxEnabled;
  final String? error;
  final bool isSubmitting;

  bool get isFull {
    final max = maxEnabled;
    return max != null && selected.length >= max;
  }

  ModesFormState copyWith({
    List<String>? selected,
    ValueGetter<String?>? error,
    bool? isSubmitting,
  }) {
    return ModesFormState(
      selected: selected ?? this.selected,
      maxEnabled: maxEnabled,
      error: error == null ? this.error : error(),
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

final modesStepControllerProvider =
    NotifierProvider.autoDispose<ModesStepController, ModesFormState>(
      ModesStepController.new,
    );

class ModesStepController extends Notifier<ModesFormState> {
  static const noneChosenMessage = 'Choose at least one mode.';

  @override
  ModesFormState build() {
    final modes = ref.read(onboardingControllerProvider).requireValue.modes;
    return ModesFormState(
      selected: modes.enabledModes,
      maxEnabled: modes.maxEnabled,
    );
  }

  void toggle(String mode) {
    if (state.isSubmitting) return;
    final modes = ref.read(onboardingControllerProvider).requireValue.modes;

    if (state.selected.contains(mode)) {
      state = state.copyWith(
        selected: [...state.selected]..remove(mode),
        error: () => null,
      );
    } else if (!modes.canEnable(mode)) {
      // The screen shows why; nothing to do here.
    } else if (state.isFull) {
      state = state.copyWith(
        error: () => state.maxEnabled == 1
            ? 'Your plan includes one mode at a time.'
            : 'Your plan includes ${state.maxEnabled} modes at a time.',
      );
    } else {
      state = state.copyWith(
        selected: [...state.selected, mode],
        error: () => null,
      );
    }
  }

  /// Switches the chosen modes on and the others off, then moves on. Returns
  /// whether that worked; if not, the form explains why.
  Future<bool> submit() async {
    if (state.isSubmitting) return false;
    if (state.selected.isEmpty) {
      state = state.copyWith(error: () => noneChosenMessage);
      return false;
    }

    final form = state.copyWith(isSubmitting: true, error: () => null);
    state = form;
    final flow = ref.read(onboardingControllerProvider.notifier);
    final saved = ref.read(onboardingControllerProvider).requireValue.modes;
    final repository = ref.read(modesRepositoryProvider);

    try {
      flow.modesSaved(await _apply(repository, saved, form.selected));
      flow.next();
      return true;
    } on ApiException catch (error) {
      // Some changes may have been saved before the failure.
      await _refresh(repository, flow);
      if (ref.mounted) {
        state = state.copyWith(isSubmitting: false, error: () => error.message);
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

  /// Brings the server in line with [selected] and returns what it then
  /// holds.
  static Future<UserModes> _apply(
    ModesRepository repository,
    UserModes saved,
    List<String> selected,
  ) async {
    final enabled = saved.enabledModes;

    // Off first: turning a new mode on while at the plan's limit would fail.
    for (final mode in enabled) {
      if (!selected.contains(mode)) {
        await repository.setEnabled(mode, enabled: false);
      }
    }
    // Then on, in the order chosen, so the first chosen becomes the main mode
    // when there's none yet.
    for (final mode in selected) {
      if (!enabled.contains(mode)) {
        await repository.setEnabled(mode, enabled: true);
      }
    }

    final result = await repository.fetch();
    return result.primaryMode == selected.first
        ? result
        : repository.makePrimary(selected.first);
  }

  Future<void> _refresh(
    ModesRepository repository,
    OnboardingController flow,
  ) async {
    try {
      flow.modesSaved(await repository.fetch());
    } on ApiException catch (error, stackTrace) {
      // The next attempt re-reads them anyway.
      developer.log(
        'Could not re-read modes after a failed save.',
        name: 'kinvo.onboarding',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
