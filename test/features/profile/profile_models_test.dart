import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/time/calendar_date.dart';
import 'package:kinvo/src/features/profile/domain/own_profile.dart';
import 'package:kinvo/src/features/profile/domain/profile_fields.dart';
import 'package:kinvo/src/features/profile/domain/profile_photo.dart';
import 'package:kinvo/src/features/profile/domain/profile_rules.dart';

Map<String, Object?> _profile({
  String? dateOfBirth = '1995-07-04',
  String? city = 'Leeds',
  String? country = 'GB',
  Object? location = const {'latitude': 53.8, 'longitude': -1.55},
  Object? completionMissing = const [
    {'key': 'prompts', 'label': 'Answer at least one prompt'},
    {'key': 'education', 'label': 'Add your education'},
  ],
}) {
  return {
    'id': 'profile-1',
    'display_name': 'Sam Taylor',
    'date_of_birth': dateOfBirth,
    'age': 31,
    'bio': 'I like long walks.',
    'job_title': 'Designer',
    'organisation': null,
    'education': null,
    'height_cm': 178,
    'city': city,
    'country': country,
    'location': location,
    'drinking': 'socially',
    'smoking': null,
    'exercise': 'often',
    'diet': '',
    'pets': null,
    'children': null,
    'interests': [
      {'id': 'i1', 'slug': 'music', 'label': 'Music', 'category': 'general'},
      {'id': 'i2', 'slug': 'coffee', 'label': 'Coffee', 'category': 'food'},
    ],
    'prompts': [
      {
        'question_id': 'q2',
        'slug': 'talk_for_hours',
        'question': 'I could talk for hours about…',
        'answer': 'Maps.',
        'position': 1,
      },
      {
        'question_id': 'q1',
        'slug': 'weekend_looks_like',
        'question': 'A perfect weekend looks like…',
        'answer': 'A long walk.',
        'position': 0,
      },
    ],
    'completion_percentage': 64,
    'completion_missing': ?completionMissing,
    'is_verified': false,
  };
}

void main() {
  group('an own profile', () {
    test('is read from GET /users/me', () {
      final profile = OwnProfile.fromJson(_profile());

      expect(profile.displayName, 'Sam Taylor');
      expect(profile.dateOfBirth, CalendarDate(1995, 7, 4));
      expect(profile.age, 31);
      expect(profile.bio, 'I like long walks.');
      expect(profile.jobTitle, 'Designer');
      expect(profile.heightCm, 178);
      expect(profile.hasLocation, isTrue);
      expect(profile.interestSlugs, ['music', 'coffee']);
      expect(profile.placeName, 'Leeds, GB');
      expect(profile.completionPercentage, 64);
      expect(profile.isVerified, isFalse);
    });

    test('keeps only the lifestyle questions answered', () {
      final profile = OwnProfile.fromJson(_profile());

      expect(profile.lifestyle, {
        ProfileField.drinking: 'socially',
        ProfileField.exercise: 'often',
      });
    });

    test('puts the prompts in the order the profile shows them', () {
      final profile = OwnProfile.fromJson(_profile());

      expect(profile.prompts.map((prompt) => prompt.slug), [
        'weekend_looks_like',
        'talk_for_hours',
      ]);
      expect(profile.prompts.first.answer, 'A long walk.');
    });

    test('says what is missing, and nothing when an older server does not', () {
      final profile = OwnProfile.fromJson(_profile());

      expect(profile.completionMissing.map((step) => step.key), [
        'prompts',
        'education',
      ]);
      expect(
        OwnProfile.fromJson(
          _profile(completionMissing: null),
        ).completionMissing,
        isEmpty,
      );
    });

    test('reads each detail by field, as the editors need', () {
      final profile = OwnProfile.fromJson(_profile());

      expect(profile.valueOf(ProfileField.displayName), 'Sam Taylor');
      expect(profile.valueOf(ProfileField.heightCm), 178);
      expect(profile.valueOf(ProfileField.drinking), 'socially');
      expect(profile.valueOf(ProfileField.education), isNull);
      expect(profile.valueOf(ProfileField.smoking), isNull);
    });

    test('may have no date of birth, location or place yet', () {
      final profile = OwnProfile.fromJson(
        _profile(dateOfBirth: null, city: null, country: null, location: null),
      );

      expect(profile.dateOfBirth, isNull);
      expect(profile.hasLocation, isFalse);
      expect(profile.placeName, isNull);
    });

    test('names whichever part of the place it knows', () {
      expect(OwnProfile.fromJson(_profile(city: null)).placeName, 'GB');
      expect(OwnProfile.fromJson(_profile(country: '')).placeName, 'Leeds');
    });

    test('fails without the fields the screens rely on', () {
      expect(
        () => OwnProfile.fromJson({'display_name': 'Sam'}),
        throwsFormatException,
      );
    });
  });

  group('profile details', () {
    test('are called by their names in the API', () {
      expect(ProfileField.heightCm.apiName, 'height_cm');
      expect(ProfileField.jobTitle.apiName, 'job_title');
      expect(ProfileField.education.hasOptions, isTrue);
      expect(ProfileField.pets.hasOptions, isTrue);
      expect(ProfileField.bio.hasOptions, isFalse);
    });

    test('turn answers into words', () {
      expect(
        profileOptionLabel(ProfileField.children, 'do_not_want_children'),
        "Don't want children",
      );
      expect(profileOptionLabel(ProfileField.pets, 'none'), 'No pets');
      expect(
        profileOptionLabel(ProfileField.education, 'postgraduate'),
        'Postgraduate degree',
      );
      expect(
        profileOptionLabel(ProfileField.drinking, 'prefer_not_to_say'),
        'Prefer not to say',
      );
      // An answer the server adds later still reads well enough.
      expect(profileOptionLabel(ProfileField.diet, 'raw_food'), 'Raw food');
    });

    test('show heights in centimetres and feet', () {
      expect(heightLabel(178), '178 cm (5 ft 10 in)');
      expect(heightLabel(152), '152 cm (5 ft 0 in)');
    });

    test('are checked as the server checks them', () {
      String? check(ProfileField field, String text) =>
          ProfileRules.textError(field, text, bioMaxLength: 500);

      expect(check(ProfileField.displayName, '  '), 'Enter your name.');
      expect(
        check(ProfileField.displayName, 'a' * 51),
        'Names can be at most 50 characters.',
      );
      expect(check(ProfileField.jobTitle, ''), isNull);
      expect(
        check(ProfileField.jobTitle, 'a' * 101),
        'Job titles can be at most 100 characters.',
      );
      expect(
        check(ProfileField.bio, 'a' * 501),
        'Bios can be at most 500 characters.',
      );
      expect(ProfileRules.promptAnswerError('  '), 'Write an answer.');
      expect(
        ProfileRules.promptAnswerError('a' * 301),
        'Answers can be at most 300 characters.',
      );
    });
  });

  group('a photo album', () {
    Map<String, Object?> photo(String id, {bool primary = false}) {
      return {
        'id': id,
        'url': 'https://storage.test/$id.jpg',
        'position': 0,
        'is_primary': primary,
        'moderation_status': id == 'b' ? 'rejected' : 'approved',
      };
    }

    const album = PhotoAlbum(
      photos: [
        ProfilePhoto(id: 'a', url: null, isPrimary: true),
        ProfilePhoto(id: 'b', url: null, isPrimary: false),
        ProfilePhoto(id: 'c', url: null, isPrimary: false),
      ],
      maxPhotos: 6,
    );

    List<String> ids(PhotoAlbum album) => [
      for (final photo in album.photos) photo.id,
    ];

    test('is read from GET /media/photos', () {
      final album = PhotoAlbum.fromJson({
        'photos': [photo('a', primary: true), photo('b')],
        'max_photos': 6,
      });

      expect(album.photos.map((p) => p.id), ['a', 'b']);
      expect(album.photos.first.isPrimary, isTrue);
      expect(album.photos.first.url, Uri.parse('https://storage.test/a.jpg'));
      expect(album.photos.last.isRemovedByModerators, isTrue);
      expect(album.isFull, isFalse);
    });

    test('promotes the next photo when the main one is removed', () {
      final remaining = album.withoutPhoto('a');

      expect(ids(remaining), ['b', 'c']);
      expect(remaining.photos.first.isPrimary, isTrue);
    });

    test('makes the first photo the main one when reordered', () {
      final reordered = album.reordered(['c', 'a', 'b']);

      expect(ids(reordered), ['c', 'a', 'b']);
      expect(reordered.photos.map((photo) => photo.isPrimary), [
        true,
        false,
        false,
      ]);
      expect(() => album.reordered(['a', 'b']), throwsArgumentError);
      expect(() => album.reordered(['a', 'a', 'b']), throwsArgumentError);
    });

    test('moves a new main photo to the front', () {
      final changed = album.withMainPhoto('c');

      expect(ids(changed), ['c', 'a', 'b']);
      expect(changed.photos.first.isPrimary, isTrue);
    });

    test('moves a dragged photo into its new place', () {
      expect(album.idsWithMove(0, 2), ['b', 'c', 'a']);
      expect(album.idsWithMove(2, 0), ['c', 'a', 'b']);
      expect(album.idsWithMove(1, 1), ['a', 'b', 'c']);
    });

    test('knows when it is full', () {
      final album = PhotoAlbum(
        photos: [
          for (var i = 0; i < 2; i++)
            ProfilePhoto(id: '$i', url: null, isPrimary: i == 0),
        ],
        maxPhotos: 2,
      );

      expect(album.isFull, isTrue);
    });
  });
}
