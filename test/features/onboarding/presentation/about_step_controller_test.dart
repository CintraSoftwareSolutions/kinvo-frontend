import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/time/calendar_date.dart';
import 'package:kinvo/src/features/onboarding/presentation/controllers/about_step_controller.dart';
import 'package:kinvo/src/features/onboarding/presentation/controllers/onboarding_controller.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fake_kinvo_server.dart';
import '../onboarding_test_setup.dart';

void main() {
  late FakeKinvoServer server;
  late OnboardingTest onboarding;

  Future<void> start() async {
    onboarding = await OnboardingTest.start(
      server,
      clock: () => DateTime(2026, 9, 15, 10),
    );
    onboarding.keepAlive(aboutStepControllerProvider);
  }

  AboutStepController form() {
    return onboarding.container.read(aboutStepControllerProvider.notifier);
  }

  AboutFormState state() {
    return onboarding.container.read(aboutStepControllerProvider);
  }

  setUp(() => server = FakeKinvoServer());

  test('starts with what the account already has', () async {
    server.bio = 'Already here.';
    await start();

    expect(state().displayName, 'Sam Taylor');
    expect(state().bio, 'Already here.');
    expect(state().needsDateOfBirth, isFalse);
  });

  test('saves the bio and moves on', () async {
    await start();

    form().updateBio('  I like long walks.  ');
    expect(await form().submit(), isTrue);

    expect(onboarding.requests('PATCH', '/users/me').single.data, {
      'bio': 'I like long walks.',
    });
    expect(onboarding.state.profile.bio, 'I like long walks.');
    expect(onboarding.state.step, OnboardingStep.photos);
  });

  test('sends only what changed, and nothing when nothing did', () async {
    server.bio = 'Already here.';
    await start();

    form().updateDisplayName('Sam T');
    await form().submit();
    expect(onboarding.requests('PATCH', '/users/me').single.data, {
      'display_name': 'Sam T',
    });

    onboarding.flow.back();
    onboarding.container.invalidate(aboutStepControllerProvider);
    expect(await form().submit(), isTrue);
    expect(onboarding.requests('PATCH', '/users/me'), hasLength(1));
  });

  test('needs a name and a bio before sending anything', () async {
    await start();

    form().updateDisplayName('   ');
    expect(await form().submit(), isFalse);

    expect(state().errors, {
      AboutField.displayName: 'Enter your name.',
      AboutField.bio: 'Write a short bio.',
    });
    expect(onboarding.requests('PATCH', '/users/me'), isEmpty);
  });

  test("shows the server's objections under their fields", () async {
    server.intercept = (options) async => options.method == 'PATCH'
        ? jsonResponse(
            400,
            errorEnvelope(
              'VALIDATION_FAILED',
              'Some fields need attention.',
              details: {
                'display_name': ['That name is not allowed.'],
              },
            ),
          )
        : null;
    await start();

    form()
      ..updateDisplayName('Admin')
      ..updateBio('Hello.');
    expect(await form().submit(), isFalse);

    expect(state().errors, {
      AboutField.displayName: 'That name is not allowed.',
    });
    expect(state().isSubmitting, isFalse);
    expect(onboarding.state.step, OnboardingStep.about);
  });

  group('for an account without a date of birth', () {
    setUp(() => server.dateOfBirth = null);

    test('asks for one and saves it with the bio', () async {
      await start();
      expect(state().needsDateOfBirth, isTrue);

      form()
        ..updateBio('Hello.')
        ..updateDateOfBirth(CalendarDate(1990, 1, 31));
      expect(await form().submit(), isTrue);

      expect(
        onboarding.requests('POST', '/onboarding/date-of-birth').single.data,
        {'date_of_birth': '1990-01-31'},
      );
      expect(onboarding.state.needsDateOfBirth, isFalse);
    });

    test('turns away anyone under 18', () async {
      await start();

      form()
        ..updateBio('Hello.')
        ..updateDateOfBirth(CalendarDate(2008, 9, 16));
      expect(await form().submit(), isFalse);

      expect(state().errors, {
        AboutField.dateOfBirth: 'You must be at least 18 to use Kinvo.',
      });
    });

    test('carries on when the date was already saved', () async {
      await start();
      server.dateOfBirth = '1990-01-31';

      form()
        ..updateBio('Hello.')
        ..updateDateOfBirth(CalendarDate(1990, 1, 31));

      expect(await form().submit(), isTrue);
      expect(onboarding.state.step, OnboardingStep.photos);
    });
  });
}
