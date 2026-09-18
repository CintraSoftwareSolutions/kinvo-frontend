import 'package:flutter/foundation.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/time/calendar_date.dart';
import 'profile_fields.dart';
import 'public_profile.dart';

/// The signed-in user's own profile, from `GET /users/me`.
@immutable
final class OwnProfile {
  const OwnProfile({
    required this.displayName,
    required this.dateOfBirth,
    required this.bio,
    required this.city,
    required this.countryCode,
    required this.hasLocation,
    required this.interests,
    this.age,
    this.jobTitle,
    this.organisation,
    this.education,
    this.heightCm,
    this.lifestyle = const {},
    this.prompts = const [],
    this.completionPercentage = 0,
    this.completionMissing = const [],
    this.isVerified = false,
  });

  factory OwnProfile.fromJson(JsonMap json) {
    if (json case {
      'display_name': final String displayName,
      'date_of_birth': final String? dateOfBirth,
      'age': final int? age,
      'bio': final String? bio,
      'job_title': final String? jobTitle,
      'organisation': final String? organisation,
      'education': final String? education,
      'height_cm': final int? heightCm,
      'city': final String? city,
      'country': final String? country,
      'location': final Object? location,
      'interests': final List<Object?> interests,
      'prompts': final List<Object?> prompts,
      'completion_percentage': final int completionPercentage,
      'is_verified': final bool isVerified,
    }) {
      return OwnProfile(
        displayName: displayName,
        dateOfBirth: dateOfBirth == null
            ? null
            : CalendarDate.tryParse(dateOfBirth),
        age: age,
        bio: bio,
        jobTitle: jobTitle,
        organisation: organisation,
        education: education,
        heightCm: heightCm,
        city: city,
        countryCode: country,
        hasLocation: location is JsonMap,
        lifestyle: {
          for (final field in ProfileField.lifestyle)
            if (json[field.apiName] case final String value
                when value.isNotEmpty)
              field: value,
        },
        interests: [
          for (final interest in interests)
            ?ProfileInterest.tryFromJson(interest),
        ],
        prompts: [
          for (final prompt in prompts) ?PromptAnswer.tryFromJson(prompt),
        ]..sort((a, b) => a.position.compareTo(b.position)),
        completionPercentage: completionPercentage,
        // Newer servers say what's missing; older ones only give the number.
        completionMissing: switch (json['completion_missing']) {
          final List<Object?> steps => [
            for (final step in steps) ?CompletionStep.tryFromJson(step),
          ],
          _ => const [],
        },
        isVerified: isVerified,
      );
    }
    throw const FormatException(
      'Expected a profile with display_name, date_of_birth, age, bio, '
      'job_title, organisation, education, height_cm, city, country, '
      'location, interests, prompts, completion_percentage and is_verified.',
    );
  }

  final String displayName;

  /// `null` for accounts made with a phone or social sign-in, until onboarding
  /// asks for it.
  final CalendarDate? dateOfBirth;

  /// Worked out by the server from the date of birth.
  final int? age;

  final String? bio;
  final String? jobTitle;
  final String? organisation;

  /// A value such as `postgraduate`; see [ProfileField.education].
  final String? education;

  final int? heightCm;
  final String? city;

  /// ISO 3166-1 alpha-2, for example `GB`.
  final String? countryCode;

  /// Whether the profile has coordinates. They're never shown back to the
  /// owner, only used to find people nearby.
  final bool hasLocation;

  /// Answers to the lifestyle questions, such as `socially` for
  /// [ProfileField.drinking]. Questions not answered are left out.
  final Map<ProfileField, String> lifestyle;

  final List<ProfileInterest> interests;

  /// Prompt answers, in the order they show.
  final List<PromptAnswer> prompts;

  /// How complete the profile is, from 0 to 100. Complete profiles are shown
  /// to more people.
  final int completionPercentage;

  /// What's left to reach 100%, the steps worth most first.
  final List<CompletionStep> completionMissing;

  final bool isVerified;

  List<String> get interestSlugs => [
    for (final interest in interests) interest.slug,
  ];

  /// Where the profile says it is, for example "Leeds, GB", or `null` when it
  /// names no place.
  String? get placeName {
    final parts = [
      for (final part in [city, countryCode])
        if (part != null && part.trim().isNotEmpty) part.trim(),
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// The value [field] holds now, as the API has it, or `null` when it's
  /// empty.
  Object? valueOf(ProfileField field) {
    return switch (field) {
      ProfileField.displayName => displayName,
      ProfileField.bio => bio,
      ProfileField.jobTitle => jobTitle,
      ProfileField.organisation => organisation,
      ProfileField.education => education,
      ProfileField.heightCm => heightCm,
      ProfileField.city => city,
      _ => lifestyle[field],
    };
  }
}

/// An answer to one of the profile prompts.
@immutable
final class PromptAnswer {
  const PromptAnswer({
    required this.slug,
    required this.question,
    required this.answer,
    this.position = 0,
  });

  static PromptAnswer? tryFromJson(Object? json) {
    if (json case {
      'slug': final String slug,
      'question': final String question,
      'answer': final String answer,
      'position': final int position,
    } when slug.isNotEmpty && question.isNotEmpty) {
      return PromptAnswer(
        slug: slug,
        question: question,
        answer: answer,
        position: position,
      );
    }
    return null;
  }

  /// The question's name in the API, for example `perfect_weekend`.
  final String slug;
  final String question;
  final String answer;
  final int position;

  PromptAnswer withAnswer(String answer) {
    return PromptAnswer(
      slug: slug,
      question: question,
      answer: answer,
      position: position,
    );
  }
}

/// Something that would make the profile more complete, such as adding a
/// photo.
@immutable
final class CompletionStep {
  const CompletionStep({required this.key, required this.label});

  static CompletionStep? tryFromJson(Object? json) {
    if (json case {
      'key': final String key,
      'label': final String label,
    } when key.isNotEmpty && label.isNotEmpty) {
      return CompletionStep(key: key, label: label);
    }
    return null;
  }

  /// Which part of the profile it's about, such as `photos`, `bio`,
  /// `interests`, `prompts`, `location`, `work`, `education` or `lifestyle`.
  final String key;

  /// What to do, in words the user can be shown, such as "Add a photo".
  final String label;
}
