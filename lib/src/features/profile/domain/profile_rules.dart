import 'profile_fields.dart';

/// The backend's rules for profile details, checked before sending.
///
/// Mirrors `src/modules/users/users.schema.ts` and the onboarding checklist in
/// kinvo-backend, messages included. The server still decides.
abstract final class ProfileRules {
  static const maxNameLength = 50;

  /// The server's bio limit. `GET /config` says it too, and wins once loaded.
  static const maxBioLength = 500;

  static const maxJobTitleLength = 100;
  static const maxOrganisationLength = 100;
  static const maxCityLength = 120;
  static const minHeightCm = 120;
  static const maxHeightCm = 250;
  static const maxPromptAnswerLength = 300;

  /// Onboarding needs a bio; editing a profile later may clear it.
  static String? bioError(String bio, {required int maxLength}) {
    final trimmed = bio.trim();
    if (trimmed.isEmpty) return 'Write a short bio.';
    if (trimmed.length > maxLength) {
      return 'Bios can be at most $maxLength characters.';
    }
    return null;
  }

  /// The most characters [field] takes, for the details typed as text.
  static int? maxLengthOf(ProfileField field, {required int bioMaxLength}) {
    return switch (field) {
      ProfileField.displayName => maxNameLength,
      ProfileField.bio => bioMaxLength,
      ProfileField.jobTitle => maxJobTitleLength,
      ProfileField.organisation => maxOrganisationLength,
      ProfileField.city => maxCityLength,
      _ => null,
    };
  }

  /// Why [text] can't be saved as [field], or `null` when it can. An empty
  /// value clears every detail except the name, which is required.
  static String? textError(
    ProfileField field,
    String text, {
    required int bioMaxLength,
  }) {
    final trimmed = text.trim();
    if (field == ProfileField.displayName && trimmed.isEmpty) {
      return 'Enter your name.';
    }
    final maxLength = maxLengthOf(field, bioMaxLength: bioMaxLength);
    if (maxLength == null || trimmed.length <= maxLength) return null;
    return switch (field) {
      ProfileField.displayName => 'Names can be at most $maxLength characters.',
      ProfileField.bio => 'Bios can be at most $maxLength characters.',
      ProfileField.jobTitle =>
        'Job titles can be at most $maxLength characters.',
      ProfileField.organisation =>
        'Organisation names can be at most $maxLength characters.',
      ProfileField.city => 'City names can be at most $maxLength characters.',
      _ => null,
    };
  }

  /// Why a prompt [answer] can't be saved, or `null` when it can.
  static String? promptAnswerError(String answer) {
    final trimmed = answer.trim();
    if (trimmed.isEmpty) return 'Write an answer.';
    if (trimmed.length > maxPromptAnswerLength) {
      return 'Answers can be at most $maxPromptAnswerLength characters.';
    }
    return null;
  }
}
