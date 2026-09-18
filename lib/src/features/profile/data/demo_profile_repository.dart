import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/config/server_config.dart';
import '../../../core/demo/demo_mode.dart';
import '../../../core/location/geo_point.dart';
import '../../../core/media/photo_processing.dart';
import '../../../core/network/api_error_code.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/time/calendar_date.dart';
import '../../../core/time/clock.dart';
import '../domain/own_profile.dart';
import '../domain/profile_fields.dart';
import '../domain/profile_photo.dart';
import '../domain/public_profile.dart';
import '../domain/user_summary.dart';
import 'profile_repository.dart';

/// The profile the demo shows as the user's own, kept for as long as the demo
/// runs. The profile and photo repositories share it, as the server's tables
/// would.
final class DemoProfile {
  DemoProfile({required Clock clock}) : _clock = clock;

  final Clock _clock;

  /// What `GET /config` would publish, which the demo can't ask for.
  static const catalogue = ServerConfig(
    modes: [],
    interests: [
      InterestOption(slug: 'design', label: 'Design', category: 'general'),
      InterestOption(
        slug: 'photography',
        label: 'Photography',
        category: 'general',
      ),
      InterestOption(slug: 'travel', label: 'Travel', category: 'general'),
      InterestOption(slug: 'books', label: 'Books', category: 'general'),
      InterestOption(slug: 'film', label: 'Film', category: 'general'),
      InterestOption(slug: 'coffee', label: 'Coffee', category: 'food'),
      InterestOption(slug: 'cooking', label: 'Cooking', category: 'food'),
      InterestOption(
        slug: 'street_food',
        label: 'Street food',
        category: 'food',
      ),
      InterestOption(slug: 'hiking', label: 'Hiking', category: 'fitness'),
      InterestOption(slug: 'running', label: 'Running', category: 'fitness'),
      InterestOption(slug: 'yoga', label: 'Yoga', category: 'fitness'),
    ],
    prompts: [
      PromptOption(
        slug: 'weekend_looks_like',
        question: 'A perfect weekend looks like…',
      ),
      PromptOption(
        slug: 'talk_for_hours',
        question: 'I could talk for hours about…',
      ),
      PromptOption(
        slug: 'never_shut_up',
        question: "I'll never shut up about…",
      ),
      PromptOption(slug: 'looking_for', question: "What I'm looking for is…"),
      PromptOption(slug: 'go_to_order', question: 'My go-to order is…'),
    ],
    lifestyleOptions: {
      'drinking': [
        'never',
        'rarely',
        'socially',
        'regularly',
        'prefer_not_to_say',
      ],
      'smoking': [
        'never',
        'rarely',
        'socially',
        'regularly',
        'prefer_not_to_say',
      ],
      'exercise': ['never', 'sometimes', 'often', 'daily', 'prefer_not_to_say'],
      'diet': [
        'omnivore',
        'vegetarian',
        'vegan',
        'pescatarian',
        'halal',
        'kosher',
        'other',
        'prefer_not_to_say',
      ],
      'pets': ['none', 'dog', 'cat', 'other', 'multiple', 'prefer_not_to_say'],
      'children': [
        'none',
        'have_children',
        'want_children',
        'do_not_want_children',
        'open',
        'prefer_not_to_say',
      ],
      'education': [
        'high_school',
        'undergraduate',
        'postgraduate',
        'doctorate',
        'other',
        'prefer_not_to_say',
      ],
    },
    limits: ProfileLimits(
      maxInterests: 10,
      maxPhotos: 6,
      bioMaxLength: 500,
      maxPrompts: 3,
    ),
  );

  static final _dateOfBirth = CalendarDate(1997, 3, 14);

  String displayName = 'Alex Johnson';
  String? bio =
      'Product designer who loves coffee, hiking and building meaningful '
      'connections.';
  String? jobTitle = 'Senior Product Designer';
  String? organisation = 'Kinvo Studio';
  String? education = 'postgraduate';
  int? heightCm = 178;
  String? city = 'Leeds';
  String? countryCode = 'GB';
  final Map<ProfileField, String> lifestyle = {
    ProfileField.drinking: 'socially',
    ProfileField.exercise: 'often',
    ProfileField.pets: 'dog',
  };
  List<String> interests = ['design', 'coffee', 'hiking', 'photography'];
  List<PromptAnswer> prompts = const [
    PromptAnswer(
      slug: 'weekend_looks_like',
      question: 'A perfect weekend looks like…',
      answer: 'A long walk in the Dales, then coffee somewhere with a view.',
    ),
  ];

  /// In order; the first is the main photo.
  List<ProfilePhoto> photos = [
    ProfilePhoto(
      id: 'demo-photo-1',
      url: Uri(scheme: 'asset', path: AppAssets.avatarBill),
      isPrimary: true,
    ),
  ];

  int _nextPhoto = 2;

  OwnProfile toOwnProfile() {
    final steps = _completion();
    final total = steps.fold(0, (sum, step) => sum + step.weight);
    final earned = steps.fold(
      0,
      (sum, step) => sum + (step.isMet ? step.weight : 0),
    );
    final missing = [
      for (final step in steps)
        if (!step.isMet) step,
    ]..sort((a, b) => b.weight.compareTo(a.weight));

    return OwnProfile(
      displayName: displayName,
      dateOfBirth: _dateOfBirth,
      age: _dateOfBirth.yearsUntil(CalendarDate.fromDateTime(_clock())),
      bio: bio,
      jobTitle: jobTitle,
      organisation: organisation,
      education: education,
      heightCm: heightCm,
      city: city,
      countryCode: countryCode,
      hasLocation: true,
      lifestyle: Map.unmodifiable(lifestyle),
      interests: [for (final slug in interests) _interest(slug)],
      prompts: [
        for (final (index, prompt) in prompts.indexed)
          PromptAnswer(
            slug: prompt.slug,
            question: prompt.question,
            answer: prompt.answer,
            position: index,
          ),
      ],
      completionPercentage: (earned / total * 100).round(),
      completionMissing: [
        for (final step in missing)
          CompletionStep(key: step.key, label: step.label),
      ],
    );
  }

  PublicProfile toPublicProfile() {
    final own = toOwnProfile();
    return PublicProfile(
      user: UserSummary(
        id: 'demo-me',
        displayName: displayName,
        age: own.age,
        photoUrl: photos.firstOrNull?.url,
        isVerified: false,
        isPremium: false,
        isOnline: true,
        lastActiveAt: _clock(),
      ),
      bio: bio,
      jobTitle: jobTitle,
      organisation: organisation,
      education: education,
      heightCm: heightCm,
      city: city,
      distanceMetres: null,
      lifestyle: {
        for (final MapEntry(:key, :value) in lifestyle.entries)
          key.apiName: value,
      },
      interests: own.interests,
      prompts: [
        for (final prompt in own.prompts)
          ProfilePrompt(
            question: prompt.question,
            answer: prompt.answer,
            position: prompt.position,
          ),
      ],
    );
  }

  PhotoAlbum toAlbum() {
    return PhotoAlbum(
      photos: List.unmodifiable(photos),
      maxPhotos: catalogue.limits.maxPhotos,
    );
  }

  String nextPhotoId() => 'demo-photo-${_nextPhoto++}';

  /// The backend's completion checklist, with its weights.
  List<({String key, String label, int weight, bool isMet})> _completion() {
    return [
      (
        key: 'photos',
        label: 'Add a photo',
        weight: 25,
        isMet: photos.isNotEmpty,
      ),
      (
        key: 'bio',
        label: 'Write a bio of at least 20 characters',
        weight: 20,
        isMet: (bio?.length ?? 0) >= 20,
      ),
      (
        key: 'interests',
        label: 'Add at least three interests',
        weight: 20,
        isMet: interests.length >= 3,
      ),
      (
        key: 'prompts',
        label: 'Answer at least one prompt',
        weight: 20,
        isMet: prompts.isNotEmpty,
      ),
      (key: 'location', label: 'Set your location', weight: 15, isMet: true),
      (
        key: 'work',
        label: 'Add your job or organisation',
        weight: 10,
        isMet: jobTitle != null || organisation != null,
      ),
      (
        key: 'education',
        label: 'Add your education',
        weight: 5,
        isMet: education != null,
      ),
      (
        key: 'lifestyle',
        label: 'Fill in your lifestyle',
        weight: 10,
        isMet: lifestyle.length >= 3,
      ),
    ];
  }

  static ProfileInterest _interest(String slug) {
    for (final option in catalogue.interests) {
      if (option.slug == slug) {
        return ProfileInterest(
          slug: slug,
          label: option.label,
          category: option.category,
        );
      }
    }
    return ProfileInterest(slug: slug, label: slug, category: 'general');
  }
}

/// The demo's own profile, from the moment the demo starts until it ends.
final demoProfileProvider = Provider<DemoProfile>((ref) {
  ref.watch(demoSessionProvider);
  return DemoProfile(clock: ref.watch(clockProvider));
});

/// [ProfileRepository] for the demo: changes are kept in [DemoProfile], and
/// nothing is sent anywhere.
final class DemoProfileRepository implements ProfileRepository {
  const DemoProfileRepository(this._profile);

  final DemoProfile _profile;

  @override
  Future<OwnProfile> fetchOwnProfile() async => _profile.toOwnProfile();

  @override
  Future<OwnProfile> updateDetails(Map<ProfileField, Object?> changes) async {
    for (final MapEntry(key: field, :value) in changes.entries) {
      final text = value is String ? value.trim() : null;
      switch (field) {
        case ProfileField.displayName:
          _profile.displayName = text ?? _profile.displayName;
        case ProfileField.bio:
          _profile.bio = text;
        case ProfileField.jobTitle:
          _profile.jobTitle = text;
        case ProfileField.organisation:
          _profile.organisation = text;
        case ProfileField.education:
          _profile.education = text;
        case ProfileField.heightCm:
          _profile.heightCm = value is int ? value : null;
        case ProfileField.city:
          _profile.city = text;
        case _:
          if (text == null) {
            _profile.lifestyle.remove(field);
          } else {
            _profile.lifestyle[field] = text;
          }
      }
    }
    return _profile.toOwnProfile();
  }

  @override
  Future<OwnProfile> updateLocation(
    GeoPoint point, {
    String? city,
    String? countryCode,
  }) async {
    _profile
      ..city = city ?? _profile.city
      ..countryCode = countryCode ?? _profile.countryCode;
    return _profile.toOwnProfile();
  }

  @override
  Future<OwnProfile> setInterests(List<String> slugs) async {
    _profile.interests = [...slugs.toSet()];
    return _profile.toOwnProfile();
  }

  @override
  Future<OwnProfile> setPrompts(List<PromptAnswer> answers) async {
    _profile.prompts = [
      for (final answer in answers) answer.withAnswer(answer.answer.trim()),
    ];
    return _profile.toOwnProfile();
  }

  @override
  Future<PublicProfile> fetchPreview() async => _profile.toPublicProfile();
}

/// [PhotosRepository] for the demo. A picked photo is kept on the device, in
/// its temporary files, and never uploaded.
final class DemoPhotosRepository implements PhotosRepository {
  const DemoPhotosRepository(this._profile);

  final DemoProfile _profile;

  @override
  Future<PhotoAlbum> fetchAlbum() async => _profile.toAlbum();

  @override
  Future<ProfilePhoto> addPhoto(PreparedPhoto photo) async {
    if (_profile.photos.length >= DemoProfile.catalogue.limits.maxPhotos) {
      throw const ApiErrorException(
        code: ApiErrorCode.conflict,
        message: 'You can have at most 6 photos. Remove one first.',
        statusCode: 409,
      );
    }
    final id = _profile.nextPhotoId();
    final folder = await Directory.systemTemp.createTemp('kinvo_demo_');
    final file = await File('${folder.path}/$id.jpg').writeAsBytes(photo.bytes);
    final added = ProfilePhoto(
      id: id,
      url: file.uri,
      isPrimary: _profile.photos.isEmpty,
    );
    _profile.photos = [..._profile.photos, added];
    return added;
  }

  @override
  Future<void> deletePhoto(String photoId) async {
    if (_profile.photos.length == 1 && _profile.photos.single.id == photoId) {
      throw const ApiErrorException(
        code: ApiErrorCode.conflict,
        message:
            'Your profile needs at least one photo. Add another one, then '
            'remove this one.',
        statusCode: 409,
      );
    }
    _profile.photos = _profile.toAlbum().withoutPhoto(photoId).photos;
  }

  @override
  Future<List<ProfilePhoto>> reorder(List<String> photoIds) async {
    _profile.photos = _profile.toAlbum().reordered(photoIds).photos;
    return _profile.photos;
  }

  @override
  Future<List<ProfilePhoto>> makeMain(String photoId) async {
    _profile.photos = _profile.toAlbum().withMainPhoto(photoId).photos;
    return _profile.photos;
  }
}
