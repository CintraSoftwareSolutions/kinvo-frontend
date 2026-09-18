import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/forms/form_errors.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/network/api_exception.dart';
import '../../../profile/data/profile_repository.dart';
import 'onboarding_controller.dart';

/// Why the device's location couldn't be used.
enum LocationProblem {
  permissionDenied(
    "Kinvo can't show you people nearby without your location. Try again "
    'and choose Allow.',
  ),
  permissionBlocked(
    'Location access is turned off for Kinvo. Turn it on in Settings, then '
    'try again.',
  ),
  servicesOff(
    "Your phone's location services are off. Turn them on, then try again.",
  ),
  unavailable(
    "We couldn't find your location. Check your connection and try again.",
  );

  const LocationProblem(this.message);

  /// Text that can be shown to the user as-is.
  final String message;

  /// Whether only the system settings can fix it.
  bool get needsSettings => this == permissionBlocked || this == servicesOff;
}

/// What's under way on the location step. Whether the profile has a location
/// is in [OnboardingState.profile].
@immutable
final class LocationStepState {
  const LocationStepState({this.isLocating = false, this.problem, this.error});

  /// Whether the location is being found or saved.
  final bool isLocating;
  final LocationProblem? problem;

  /// Why saving the location failed.
  final String? error;
}

final locationStepControllerProvider =
    NotifierProvider.autoDispose<LocationStepController, LocationStepState>(
      LocationStepController.new,
    );

class LocationStepController extends Notifier<LocationStepState> {
  @override
  LocationStepState build() => const LocationStepState();

  /// Finds the device's approximate location and saves it to the profile.
  Future<void> shareLocation() async {
    if (state.isLocating) return;
    state = const LocationStepState(isLocating: true);
    final flow = ref.read(onboardingControllerProvider.notifier);
    final profiles = ref.read(profileRepositoryProvider);

    try {
      switch (await ref
          .read(locationServiceProvider)
          .findApproximateLocation()) {
        case LocationFound(:final point, :final city, :final countryCode):
          flow.profileSaved(
            await profiles.updateLocation(
              point,
              city: city,
              countryCode: countryCode,
            ),
          );
          _finish();
        case LocationPermissionDenied(:final canAskAgain):
          _finish(
            problem: canAskAgain
                ? LocationProblem.permissionDenied
                : LocationProblem.permissionBlocked,
          );
        case LocationServicesDisabled():
          _finish(problem: LocationProblem.servicesOff);
        case LocationUnavailable():
          _finish(problem: LocationProblem.unavailable);
      }
    } on ApiException catch (error) {
      _finish(error: error.message);
    } on Object {
      _finish(error: unexpectedFailureMessage);
      rethrow;
    }
  }

  /// Opens the settings that can fix the current problem.
  Future<void> openSettings() async {
    final service = ref.read(locationServiceProvider);
    switch (state.problem) {
      case LocationProblem.permissionBlocked:
        await service.openAppSettings();
      case LocationProblem.servicesOff:
        await service.openLocationSettings();
      case LocationProblem.permissionDenied ||
          LocationProblem.unavailable ||
          null:
        break;
    }
  }

  void _finish({LocationProblem? problem, String? error}) {
    if (!ref.mounted) return;
    state = LocationStepState(problem: problem, error: error);
  }
}
