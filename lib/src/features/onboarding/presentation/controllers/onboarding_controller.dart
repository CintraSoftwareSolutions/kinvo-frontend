import 'dart:async';

import 'package:flutter/foundation.dart';
// Riverpod's AsyncError is an AsyncValue; waiting for several futures reports
// failures with dart:async's.
import 'package:flutter_riverpod/flutter_riverpod.dart' hide AsyncError;

import '../../../../core/auth/account_providers.dart';
import '../../../../core/config/server_config.dart';
import '../../../../core/config/server_config_providers.dart';
import '../../../../core/network/api_error_code.dart';
import '../../../../core/network/api_exception.dart';
import '../../../modes/data/modes_repository.dart';
import '../../../modes/domain/user_modes.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../profile/domain/own_profile.dart';
import '../../../profile/domain/profile_photo.dart';
import '../../data/onboarding_repository.dart';
import '../../domain/onboarding_status.dart';

/// The steps of onboarding, in order, with the requirements each one meets.
enum OnboardingStep {
  about({
    OnboardingRequirement.displayName,
    OnboardingRequirement.dateOfBirth,
    OnboardingRequirement.bio,
  }),
  photos({OnboardingRequirement.photo}),
  interests({OnboardingRequirement.interests}),
  modes({OnboardingRequirement.mode}),
  location({OnboardingRequirement.location});

  const OnboardingStep(this.requirements);

  final Set<OnboardingRequirement> requirements;

  bool get isFirst => index == 0;
  bool get isLast => index == values.length - 1;

  /// The first step that meets any of [missing]. When nothing is missing,
  /// the last step, where onboarding is finished.
  static OnboardingStep firstFor(Set<OnboardingRequirement> missing) {
    return values.firstWhere(
      (step) => step.requirements.any(missing.contains),
      orElse: () => values.last,
    );
  }
}

@immutable
final class OnboardingState {
  const OnboardingState({
    required this.step,
    required this.config,
    required this.profile,
    required this.album,
    required this.modes,
    required this.needsDateOfBirth,
    this.isFinishing = false,
    this.error,
  });

  final OnboardingStep step;
  final ServerConfig config;
  final OwnProfile profile;
  final PhotoAlbum album;
  final UserModes modes;

  /// Whether the account still has no date of birth, as after a social
  /// sign-in.
  final bool needsDateOfBirth;

  /// Whether onboarding is being finished. Stays true once it has been, while
  /// the app moves on.
  final bool isFinishing;

  /// Why onboarding couldn't be finished, shown on the step needing attention.
  final String? error;

  OnboardingState copyWith({
    OnboardingStep? step,
    OwnProfile? profile,
    PhotoAlbum? album,
    UserModes? modes,
    bool? needsDateOfBirth,
    bool? isFinishing,
    ValueGetter<String?>? error,
  }) {
    return OnboardingState(
      step: step ?? this.step,
      config: config,
      profile: profile ?? this.profile,
      album: album ?? this.album,
      modes: modes ?? this.modes,
      needsDateOfBirth: needsDateOfBirth ?? this.needsDateOfBirth,
      isFinishing: isFinishing ?? this.isFinishing,
      error: error == null ? this.error : error(),
    );
  }
}

/// Onboarding, loaded afresh each time it opens.
final onboardingControllerProvider =
    AsyncNotifierProvider.autoDispose<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );

/// What the account already has, which step is showing, and finishing.
///
/// The steps save their own changes, then report them here, so going back to
/// a step shows what was saved.
class OnboardingController extends AsyncNotifier<OnboardingState> {
  static const _updateAppMessage =
      "Your profile needs something this version of Kinvo can't set up. "
      'Update the app to continue.';

  @override
  Future<OnboardingState> build() async {
    final onboarding = ref.watch(onboardingRepositoryProvider);
    final profiles = ref.watch(profileRepositoryProvider);
    final photos = ref.watch(photosRepositoryProvider);
    final modes = ref.watch(modesRepositoryProvider);

    // Everything the steps show is loaded up front, so moving between them
    // never waits on the network.
    final (status, profile, album, userModes, config) = await _waitForAll((
      onboarding.fetchStatus(),
      profiles.fetchOwnProfile(),
      photos.fetchAlbum(),
      modes.fetch(),
      ref.watch(serverConfigProvider.future),
    ));

    return OnboardingState(
      step: OnboardingStep.firstFor(status.missing),
      config: config,
      profile: profile,
      album: album,
      modes: userModes,
      needsDateOfBirth: status.missing.contains(
        OnboardingRequirement.dateOfBirth,
      ),
    );
  }

  /// Loads everything again after loading failed.
  void reload() {
    // A failed catalogue load stays failed until it's asked for again.
    if (ref.read(serverConfigProvider).hasError) {
      ref.invalidate(serverConfigProvider);
    }
    ref.invalidateSelf();
  }

  void back() {
    _update((current) {
      if (current.step.isFirst) return current;
      return current.copyWith(
        step: OnboardingStep.values[current.step.index - 1],
        error: () => null,
      );
    });
  }

  void next() {
    _update((current) {
      if (current.step.isLast) return current;
      return current.copyWith(
        step: OnboardingStep.values[current.step.index + 1],
        error: () => null,
      );
    });
  }

  void profileSaved(OwnProfile profile) {
    _update((current) => current.copyWith(profile: profile));
  }

  void dateOfBirthSaved() {
    _update((current) => current.copyWith(needsDateOfBirth: false));
  }

  void photoAdded(ProfilePhoto photo) {
    _update(
      (current) => current.copyWith(album: current.album.withPhoto(photo)),
    );
  }

  void photoRemoved(String photoId) {
    _update(
      (current) => current.copyWith(album: current.album.withoutPhoto(photoId)),
    );
  }

  void modesSaved(UserModes modes) {
    _update((current) => current.copyWith(modes: modes));
  }

  /// Finishes onboarding. The router opens the app once the account reads as
  /// onboarded; until then, this stays in progress.
  Future<void> finish() async {
    final current = state.value;
    if (current == null || current.isFinishing) return;
    state = AsyncData(current.copyWith(isFinishing: true, error: () => null));

    try {
      await ref.read(onboardingRepositoryProvider).complete();
      if (!ref.mounted) return;
      final account = await ref.refresh(currentAccountProvider.future);
      if (account != null && !account.isOnboarded) {
        throw const UnexpectedResponseException(
          reason: 'Onboarding was completed, but the account is not onboarded.',
        );
      }
    } on ApiException catch (error) {
      _update(
        (current) => switch (error) {
          ApiErrorException(code: ApiErrorCode.onboardingIncomplete) =>
            _returnToMissing(current, error),
          _ => current.copyWith(isFinishing: false, error: () => error.message),
        },
      );
    }
  }

  OnboardingState _returnToMissing(
    OnboardingState current,
    ApiErrorException error,
  ) {
    final names = switch (error.details?['missing']) {
      final List<Object?> names => names,
      _ => const <Object?>[],
    };
    final missing = OnboardingStatus.readRequirements(names);
    if (missing.known.isEmpty) {
      return current.copyWith(
        isFinishing: false,
        error: () =>
            missing.unknown.isEmpty ? error.message : _updateAppMessage,
      );
    }
    return current.copyWith(
      step: OnboardingStep.firstFor(missing.known),
      needsDateOfBirth:
          current.needsDateOfBirth ||
          missing.known.contains(OnboardingRequirement.dateOfBirth),
      isFinishing: false,
      error: () => error.message,
    );
  }

  void _update(OnboardingState Function(OnboardingState current) change) {
    if (!ref.mounted) return;
    if (state.value case final current?) {
      state = AsyncData(change(current));
    }
  }
}

/// Waits for all five loads. A failure is rethrown as itself, rather than
/// wrapped in a [ParallelWaitError], so the screen can explain it.
Future<(A, B, C, D, E)> _waitForAll<A, B, C, D, E>(
  (Future<A>, Future<B>, Future<C>, Future<D>, Future<E>) futures,
) async {
  try {
    return await futures.wait;
  } on ParallelWaitError<
    (A?, B?, C?, D?, E?),
    (AsyncError?, AsyncError?, AsyncError?, AsyncError?, AsyncError?)
  > catch (error) {
    final (a, b, c, d, e) = error.errors;
    final first = [a, b, c, d, e].nonNulls.first;
    Error.throwWithStackTrace(first.error, first.stackTrace);
  }
}
