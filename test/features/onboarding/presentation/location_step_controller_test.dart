import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/location/geo_point.dart';
import 'package:kinvo/src/core/location/location_service.dart';
import 'package:kinvo/src/features/onboarding/presentation/controllers/location_step_controller.dart';
import 'package:kinvo/src/features/onboarding/presentation/controllers/onboarding_controller.dart';

import '../../../helpers/device_fakes.dart';
import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fake_kinvo_server.dart';
import '../onboarding_test_setup.dart';

void main() {
  late FakeKinvoServer server;
  late OnboardingTest onboarding;

  LocationStepController location() {
    return onboarding.container.read(locationStepControllerProvider.notifier);
  }

  LocationStepState progress() {
    return onboarding.container.read(locationStepControllerProvider);
  }

  FakeLocationService device() => onboarding.backend.locationService;

  setUp(() async {
    server = FakeKinvoServer();
    onboarding = await OnboardingTest.start(server);
    onboarding
      ..keepAlive(locationStepControllerProvider)
      ..goTo(OnboardingStep.location);
  });

  test('saves the approximate location and names the place', () async {
    await location().shareLocation();

    expect(onboarding.requests('PATCH', '/users/me/location').single.data, {
      'latitude': 53.8,
      'longitude': -1.55,
      'city': 'Leeds',
      'country': 'GB',
    });
    expect(onboarding.state.profile.hasLocation, isTrue);
    expect(onboarding.state.profile.placeName, 'Leeds, GB');
    expect(progress().isLocating, isFalse);
    expect(progress().problem, isNull);
  });

  test('saves a location the device could not name', () async {
    device().result = const LocationFound(
      point: GeoPoint(latitude: 1.23, longitude: 4.56),
    );

    await location().shareLocation();

    expect(onboarding.requests('PATCH', '/users/me/location').single.data, {
      'latitude': 1.23,
      'longitude': 4.56,
    });
  });

  test('explains a refusal that asking again can fix', () async {
    device().result = const LocationPermissionDenied(canAskAgain: true);

    await location().shareLocation();

    expect(progress().problem, LocationProblem.permissionDenied);
    expect(progress().problem!.needsSettings, isFalse);
    expect(onboarding.requests('PATCH', '/users/me/location'), isEmpty);
  });

  test('sends a lasting refusal to the app settings', () async {
    device().result = const LocationPermissionDenied(canAskAgain: false);

    await location().shareLocation();
    await location().openSettings();

    expect(progress().problem, LocationProblem.permissionBlocked);
    expect(device().appSettingsOpened, 1);
    expect(device().locationSettingsOpened, 0);
  });

  test('sends location services being off to the location settings', () async {
    device().result = const LocationServicesDisabled();

    await location().shareLocation();
    await location().openSettings();

    expect(progress().problem, LocationProblem.servicesOff);
    expect(device().locationSettingsOpened, 1);
  });

  test('explains when no location could be found', () async {
    device().result = const LocationUnavailable();

    await location().shareLocation();

    expect(progress().problem, LocationProblem.unavailable);
  });

  test('clears the last problem when trying again works', () async {
    device().result = const LocationUnavailable();
    await location().shareLocation();

    device().result = FakeLocationService.leeds;
    await location().shareLocation();

    expect(progress().problem, isNull);
    expect(onboarding.state.profile.hasLocation, isTrue);
  });

  test('explains when the location could not be saved', () async {
    server.intercept = (options) async => options.method == 'PATCH'
        ? jsonResponse(503, errorEnvelope('SERVICE_UNAVAILABLE', 'Try later.'))
        : null;

    await location().shareLocation();

    expect(progress().error, 'Try later.');
    expect(onboarding.state.profile.hasLocation, isFalse);
  });
}
