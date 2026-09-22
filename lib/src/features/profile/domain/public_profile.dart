import 'package:flutter/foundation.dart';

import '../../../core/network/api_envelope.dart';
import 'person_photos.dart';
import 'user_summary.dart';

/// Someone else's full profile, as they chose to show it.
@immutable
final class PublicProfile {
  const PublicProfile({
    required this.user,
    required this.photos,
    required this.bio,
    required this.jobTitle,
    required this.organisation,
    required this.education,
    required this.heightCm,
    required this.city,
    required this.distanceMetres,
    required this.lifestyle,
    required this.interests,
    required this.prompts,
  });

  /// Reads the `data` of `GET /users/{id}`.
  factory PublicProfile.fromJson(JsonMap json) {
    if (json case {
      'user': final JsonMap user,
      'bio': final String? bio,
      'job_title': final String? jobTitle,
      'organisation': final String? organisation,
      'education': final String? education,
      'height_cm': final int? heightCm,
      'city': final String? city,
      'distance_metres': final num? distanceMetres,
      'interests': final List<Object?> interests,
      'prompts': final List<Object?> prompts,
    }) {
      return PublicProfile(
        user: UserSummary.fromJson(user),
        photos: PersonPhotoRef.listFromJson(json['photos']),
        bio: bio,
        jobTitle: jobTitle,
        organisation: organisation,
        education: education,
        heightCm: heightCm,
        city: city,
        distanceMetres: distanceMetres?.toDouble(),
        lifestyle: {
          for (final key in lifestyleKeys)
            if (json[key] case final String value when value.isNotEmpty)
              key: value,
        },
        interests: [
          for (final interest in interests)
            ?ProfileInterest.tryFromJson(interest),
        ],
        prompts: [
          for (final prompt in prompts) ?ProfilePrompt.tryFromJson(prompt),
        ]..sort((a, b) => a.position.compareTo(b.position)),
      );
    }
    throw const FormatException(
      'Expected a profile with user, bio, job_title, organisation, education, '
      'height_cm, city, distance_metres, interests and prompts.',
    );
  }

  /// The lifestyle answers a profile can have, in the order to show them.
  static const lifestyleKeys = [
    'drinking',
    'smoking',
    'exercise',
    'diet',
    'pets',
    'children',
  ];

  final UserSummary user;

  /// Their approved photos, in the order they arranged them. Empty for
  /// someone with none, and the first is the one on [UserSummary.photoUrl].
  final List<PersonPhotoRef> photos;

  final String? bio;
  final String? jobTitle;
  final String? organisation;

  /// Their level of education, as a value such as `postgraduate`.
  final String? education;

  final int? heightCm;
  final String? city;

  /// How far away they are, or `null` when either person has no location.
  final double? distanceMetres;

  /// Lifestyle answers they gave, by [lifestyleKeys] key, as values such as
  /// `socially`. Questions they skipped are left out.
  final Map<String, String> lifestyle;

  final List<ProfileInterest> interests;

  /// Their answers to profile prompts, in the order they chose.
  final List<ProfilePrompt> prompts;
}

@immutable
final class ProfileInterest {
  const ProfileInterest({
    required this.slug,
    required this.label,
    required this.category,
  });

  static ProfileInterest? tryFromJson(Object? json) {
    if (json case {
      'slug': final String slug,
      'label': final String label,
      'category': final String category,
    } when slug.isNotEmpty && label.isNotEmpty) {
      return ProfileInterest(slug: slug, label: label, category: category);
    }
    return null;
  }

  final String slug;
  final String label;
  final String category;
}

@immutable
final class ProfilePrompt {
  const ProfilePrompt({
    required this.question,
    required this.answer,
    required this.position,
  });

  static ProfilePrompt? tryFromJson(Object? json) {
    if (json case {
      'question': final String question,
      'answer': final String answer,
      'position': final int position,
    } when question.isNotEmpty && answer.isNotEmpty) {
      return ProfilePrompt(
        question: question,
        answer: answer,
        position: position,
      );
    }
    return null;
  }

  final String question;
  final String answer;
  final int position;
}
