import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/features/onboarding/presentation/controllers/interests_step_controller.dart';
import 'package:kinvo/src/features/onboarding/presentation/controllers/modes_step_controller.dart';
import 'package:kinvo/src/features/onboarding/presentation/controllers/onboarding_controller.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fake_kinvo_server.dart';
import '../onboarding_test_setup.dart';

void main() {
  late FakeKinvoServer server;

  setUp(() => server = FakeKinvoServer());

  group('interests', () {
    late OnboardingTest onboarding;

    InterestsStepController interests() {
      return onboarding.container.read(
        interestsStepControllerProvider.notifier,
      );
    }

    InterestsFormState state() {
      return onboarding.container.read(interestsStepControllerProvider);
    }

    Future<void> start() async {
      onboarding = await OnboardingTest.start(server);
      onboarding
        ..keepAlive(interestsStepControllerProvider)
        ..goTo(OnboardingStep.interests);
    }

    test('saves the chosen interests and moves on', () async {
      await start();

      interests()
        ..toggle('music')
        ..toggle('coffee');
      expect(await interests().submit(), isTrue);

      expect(onboarding.requests('PUT', '/users/me/interests').single.data, {
        'interests': ['music', 'coffee'],
      });
      expect(onboarding.state.profile.interestSlugs, ['music', 'coffee']);
      expect(onboarding.state.step, OnboardingStep.modes);
    });

    test('starts with saved interests the server still offers', () async {
      server.interests = ['travel', 'retired_interest'];
      await start();

      expect(state().selected, ['travel']);
    });

    test('needs at least one', () async {
      await start();

      expect(await interests().submit(), isFalse);

      expect(state().error, InterestsStepController.noneChosenMessage);
      expect(onboarding.requests('PUT', '/users/me/interests'), isEmpty);
    });

    test('allows no more than the limit the server sets', () async {
      server.maxInterests = 2;
      await start();

      interests()
        ..toggle('music')
        ..toggle('travel')
        ..toggle('coffee');

      expect(state().selected, ['music', 'travel']);
      expect(state().error, 'You can choose up to 2 interests.');

      interests().toggle('music');
      expect(state().error, isNull);
    });

    test('does not save interests that have not changed', () async {
      server.interests = ['music'];
      await start();

      expect(await interests().submit(), isTrue);

      expect(onboarding.requests('PUT', '/users/me/interests'), isEmpty);
      expect(onboarding.state.step, OnboardingStep.modes);
    });

    test("shows the server's reason for refusing them", () async {
      server.intercept = (options) async => options.method == 'PUT'
          ? jsonResponse(
              400,
              errorEnvelope(
                'VALIDATION_FAILED',
                'Some fields need attention.',
                details: {
                  'interests': ['Unknown interests: music.'],
                },
              ),
            )
          : null;
      await start();

      interests().toggle('music');
      expect(await interests().submit(), isFalse);

      expect(state().error, 'Unknown interests: music.');
      expect(state().isSubmitting, isFalse);
    });
  });

  group('modes', () {
    late OnboardingTest onboarding;

    ModesStepController modes() {
      return onboarding.container.read(modesStepControllerProvider.notifier);
    }

    ModesFormState state() {
      return onboarding.container.read(modesStepControllerProvider);
    }

    Future<void> start() async {
      onboarding = await OnboardingTest.start(server);
      onboarding
        ..keepAlive(modesStepControllerProvider)
        ..goTo(OnboardingStep.modes);
    }

    test('switches the chosen modes on, the first as the main mode', () async {
      await start();

      modes()
        ..toggle('networking')
        ..toggle('dating');
      expect(await modes().submit(), isTrue);

      expect(server.enabledModes, ['networking', 'dating']);
      expect(server.primaryMode, 'networking');
      expect(onboarding.state.modes.enabledModes, ['networking', 'dating']);
      expect(onboarding.state.step, OnboardingStep.location);
    });

    test('makes the first choice main even if another was main', () async {
      server
        ..enabledModes.addAll(['dating', 'networking'])
        ..primaryMode = 'dating';
      await start();
      expect(state().selected, ['dating', 'networking']);

      modes()
        ..toggle('dating')
        ..toggle('study_buddy');
      await modes().submit();

      expect(server.enabledModes, ['networking', 'study_buddy']);
      expect(server.primaryMode, 'networking');
    });

    test(
      'swaps a mode at the limit by switching the old one off first',
      () async {
        server
          ..maxModes = 2
          ..enabledModes.addAll(['dating', 'networking'])
          ..primaryMode = 'dating';
        await start();

        modes()
          ..toggle('networking')
          ..toggle('study_buddy');
        expect(await modes().submit(), isTrue);

        expect(server.enabledModes, ['dating', 'study_buddy']);
      },
    );

    test('keeps within the plan and skips modes that need more', () async {
      server.maxModes = 1;
      await start();

      modes()
        ..toggle('cuddle')
        ..toggle('dating')
        ..toggle('networking');

      expect(state().selected, ['dating']);
      expect(state().error, 'Your plan includes one mode at a time.');
    });

    test('needs at least one mode', () async {
      await start();

      expect(await modes().submit(), isFalse);

      expect(state().error, ModesStepController.noneChosenMessage);
    });

    test('shows what the server refused and what it kept', () async {
      server.intercept = (options) async =>
          options.method == 'PATCH' && options.uri.path.endsWith('/networking')
          ? jsonResponse(
              403,
              errorEnvelope(
                'PREMIUM_REQUIRED',
                'Your plan includes 1 modes at a time. Upgrade for more.',
              ),
            )
          : null;
      await start();

      modes()
        ..toggle('dating')
        ..toggle('networking');
      expect(await modes().submit(), isFalse);

      expect(state().error, contains('Upgrade for more'));
      expect(state().isSubmitting, isFalse);
      // Dating was saved before the refusal, and the form knows it.
      expect(onboarding.state.modes.enabledModes, ['dating']);
      expect(onboarding.state.step, OnboardingStep.modes);
    });
  });
}
