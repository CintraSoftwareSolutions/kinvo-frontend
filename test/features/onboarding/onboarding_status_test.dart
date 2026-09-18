import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/features/onboarding/domain/onboarding_status.dart';
import 'package:kinvo/src/features/onboarding/presentation/controllers/onboarding_controller.dart';

void main() {
  test('reads what onboarding is still missing', () {
    final status = OnboardingStatus.fromJson({
      'is_complete': false,
      'can_complete': false,
      'missing': ['bio', 'photo', 'pronouns'],
    });

    expect(status.isComplete, isFalse);
    expect(status.missing, {
      OnboardingRequirement.bio,
      OnboardingRequirement.photo,
    });
    // Added to the backend after this version of the app.
    expect(status.unknownMissing, ['pronouns']);
  });

  group('the step to show', () {
    test('is the first one with something missing', () {
      expect(
        OnboardingStep.firstFor({
          OnboardingRequirement.location,
          OnboardingRequirement.interests,
        }),
        OnboardingStep.interests,
      );
      expect(
        OnboardingStep.firstFor({OnboardingRequirement.dateOfBirth}),
        OnboardingStep.about,
      );
    });

    test('is the last one when nothing is missing', () {
      expect(OnboardingStep.firstFor({}), OnboardingStep.location);
    });
  });
}
