import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/auth/account_providers.dart';
import 'package:kinvo/src/core/network/api_exception.dart';
import 'package:kinvo/src/features/onboarding/presentation/controllers/onboarding_controller.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fake_kinvo_server.dart';
import '../../../helpers/test_backend.dart';
import '../onboarding_test_setup.dart';

void main() {
  late FakeKinvoServer server;

  setUp(() => server = FakeKinvoServer());

  group('loading', () {
    test('a new account starts at the first step', () async {
      final onboarding = await OnboardingTest.start(server);

      expect(onboarding.state.step, OnboardingStep.about);
      expect(onboarding.state.profile.displayName, 'Sam Taylor');
      expect(onboarding.state.config.interests, isNotEmpty);
      expect(onboarding.state.needsDateOfBirth, isFalse);
    });

    test('resumes at the first step that still needs something', () async {
      server.completeProfile(except: {'interests', 'location'});

      final onboarding = await OnboardingTest.start(server);

      expect(onboarding.state.step, OnboardingStep.interests);
      expect(onboarding.state.album.photos, hasLength(1));
      expect(onboarding.state.modes.enabledModes, ['dating']);
    });

    test('with nothing missing, opens where onboarding is finished', () async {
      server.completeProfile();

      final onboarding = await OnboardingTest.start(server);

      expect(onboarding.state.step, OnboardingStep.location);
    });

    test('asks for a date of birth only when the account has none', () async {
      server.dateOfBirth = null;

      final onboarding = await OnboardingTest.start(server);

      expect(onboarding.state.needsDateOfBirth, isTrue);
      expect(onboarding.state.step, OnboardingStep.about);
    });

    test('reports why loading failed, and loads again on request', () async {
      var offline = true;
      server.intercept = (options) async {
        if (offline && options.uri.path.endsWith('/media/photos')) {
          throw const SocketException('Network is unreachable');
        }
        return null;
      };
      final backend = TestBackend(respond: server.respond);
      await backend.tokenStore.write(liveSession());
      final container = backend.createContainer()
        ..listen(onboardingControllerProvider, (_, _) {});

      await expectLater(
        container.read(onboardingControllerProvider.future),
        throwsA(isA<NetworkException>()),
      );

      offline = false;
      container.read(onboardingControllerProvider.notifier).reload();

      final state = await container.read(onboardingControllerProvider.future);
      expect(state.step, OnboardingStep.about);
    });
  });

  test('moves between steps without leaving onboarding', () async {
    final onboarding = await OnboardingTest.start(server);

    onboarding.flow.back();
    expect(onboarding.state.step, OnboardingStep.about);

    for (var i = 0; i < OnboardingStep.values.length + 1; i++) {
      onboarding.flow.next();
    }
    expect(onboarding.state.step, OnboardingStep.location);

    onboarding.flow.back();
    expect(onboarding.state.step, OnboardingStep.modes);
  });

  group('finishing', () {
    test('lets the account into the app', () async {
      server.completeProfile();
      final onboarding = await OnboardingTest.start(server);

      await onboarding.flow.finish();

      expect(onboarding.requests('POST', '/onboarding/complete'), hasLength(1));
      final account = onboarding.container.read(currentAccountProvider).value;
      expect(account?.isOnboarded, isTrue);
      // The router takes over from here.
      expect(onboarding.state.isFinishing, isTrue);
    });

    test('goes back to whatever the server says is missing', () async {
      server.completeProfile();
      final onboarding = await OnboardingTest.start(server);
      expect(onboarding.state.step, OnboardingStep.location);
      // Removed on another device after onboarding loaded here.
      server.photos.clear();

      await onboarding.flow.finish();

      expect(onboarding.state.step, OnboardingStep.photos);
      expect(
        onboarding.state.error,
        'Finish setting up your profile to continue.',
      );
      expect(onboarding.state.isFinishing, isFalse);
    });

    test('asks for an app update when it cannot meet a requirement', () async {
      server
        ..completeProfile()
        ..intercept = (options) async =>
            options.uri.path.endsWith('/onboarding/complete')
            ? jsonResponse(
                403,
                errorEnvelope(
                  'ONBOARDING_INCOMPLETE',
                  'Finish setting up your profile to continue.',
                  details: {
                    'missing': ['pronouns'],
                  },
                ),
              )
            : null;
      final onboarding = await OnboardingTest.start(server);

      await onboarding.flow.finish();

      expect(onboarding.state.step, OnboardingStep.location);
      expect(onboarding.state.error, contains('Update the app'));
    });

    test('explains a failure and can be tried again', () async {
      server.completeProfile();
      var offline = true;
      server.intercept = (options) async {
        if (offline && options.uri.path.endsWith('/onboarding/complete')) {
          throw const SocketException('Network is unreachable');
        }
        return null;
      };
      final onboarding = await OnboardingTest.start(server);

      await onboarding.flow.finish();
      expect(onboarding.state.error, contains('Check your internet'));
      expect(onboarding.state.isFinishing, isFalse);

      offline = false;
      await onboarding.flow.finish();
      expect(server.isOnboarded, isTrue);
      expect(onboarding.state.error, isNull);
    });
  });
}
