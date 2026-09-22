import 'package:flutter/foundation.dart';

import '../../../core/assets/app_assets.dart';
import '../../profile/domain/person_photos.dart';
import '../../profile/domain/public_profile.dart';
import '../../profile/domain/user_summary.dart';

/// Someone the demo shows. The demo runs without an account or a connection,
/// so its people and their photos ship with the app.
@immutable
final class DemoPerson {
  const DemoPerson({
    required this.id,
    required this.name,
    required this.age,
    required this.homeMode,
    required this.milesAway,
    required this.bio,
    required this.interests,
    required this.photoAsset,
    required this.activeAgo,
    this.isVerified = true,
    this.isPremium = false,
    this.likesBack = false,
  });

  final String id;
  final String name;
  final int age;

  /// The mode whose deck shows them first.
  final String homeMode;

  final int milesAway;
  final String bio;

  /// Interest slugs, which read well once turned into words.
  final List<String> interests;

  final String photoAsset;

  /// How long ago they were last around. Zero means online now.
  final Duration activeAgo;

  final bool isVerified;
  final bool isPremium;

  /// Whether liking them makes a match, so the demo can show one.
  final bool likesBack;

  double get distanceMetres => milesAway * 1609.344;

  /// Photos in the demo are bundled images, addressed with an `asset:` link.
  Uri get photoUrl => Uri(scheme: 'asset', path: photoAsset);

  /// The demo ships one picture per person, so a demo gallery has one photo
  /// in it and shows no counter. Real profiles carry up to six.
  List<PersonPhotoRef> get photos => [
    PersonPhotoRef(id: '$id-photo', url: photoUrl),
  ];

  UserSummary summaryAt(DateTime now) {
    return UserSummary(
      id: id,
      displayName: name,
      age: age,
      photoUrl: photoUrl,
      isVerified: isVerified,
      isPremium: isPremium,
      isOnline: activeAgo == Duration.zero,
      lastActiveAt: now.subtract(activeAgo),
    );
  }

  PublicProfile profileAt(DateTime now) {
    return PublicProfile(
      user: summaryAt(now),
      photos: photos,
      bio: bio,
      jobTitle: null,
      organisation: null,
      education: null,
      heightCm: null,
      city: 'London',
      distanceMetres: distanceMetres,
      lifestyle: const {},
      interests: [
        for (final slug in interests)
          ProfileInterest(slug: slug, label: _words(slug), category: 'general'),
      ],
      prompts: const [],
    );
  }

  static String _words(String slug) {
    final words = slug.replaceAll('_', ' ');
    return words[0].toUpperCase() + words.substring(1);
  }
}

/// The demo's people, in the order a deck shows them.
const demoPeople = <DemoPerson>[
  DemoPerson(
    id: 'sarah',
    name: 'Sarah',
    age: 28,
    homeMode: 'dating',
    milesAway: 2,
    bio:
        'Love exploring new coffee shops and weekend hikes. Looking for '
        'someone who values deep conversations.',
    interests: ['coffee', 'hiking', 'photography', 'travel'],
    photoAsset: AppAssets.avatarSarah,
    activeAgo: Duration.zero,
    likesBack: true,
  ),
  DemoPerson(
    id: 'maya',
    name: 'Maya',
    age: 30,
    homeMode: 'cuddle',
    milesAway: 4,
    bio:
        'Soft-spoken creative who loves movie nights, candlelit corners and '
        'emotionally safe check-ins.',
    interests: ['cozy_nights', 'journaling', 'tea'],
    photoAsset: AppAssets.avatarMaya,
    activeAgo: Duration(minutes: 41),
  ),
  DemoPerson(
    id: 'olivia',
    name: 'Olivia',
    age: 27,
    homeMode: 'foodie',
    milesAway: 3,
    bio:
        'Foodie on a mission to try every cuisine in the city. Who wants to '
        'be my dining partner?',
    interests: ['food', 'cooking', 'wine', 'travel'],
    photoAsset: AppAssets.avatarOlivia,
    activeAgo: Duration.zero,
    isPremium: true,
  ),
  DemoPerson(
    id: 'marcus',
    name: 'Marcus',
    age: 32,
    homeMode: 'networking',
    milesAway: 5,
    bio:
        'Software engineer passionate about AI and startups. Always up for '
        'networking over coffee.',
    interests: ['tech', 'ai', 'startups'],
    photoAsset: AppAssets.avatarMarcus,
    activeAgo: Duration(hours: 2),
    isPremium: true,
    likesBack: true,
  ),
  DemoPerson(
    id: 'noah',
    name: 'Noah',
    age: 31,
    homeMode: 'pet_dates',
    milesAway: 6,
    bio:
        'Dog dad looking for pet-friendly parks, new walking trails and '
        'easygoing people who love animals.',
    interests: ['dog_parks', 'pet_cafes', 'weekend_walks'],
    photoAsset: AppAssets.avatarNoah,
    activeAgo: Duration.zero,
    isPremium: true,
  ),
  DemoPerson(
    id: 'emma',
    name: 'Emma',
    age: 25,
    homeMode: 'study_buddy',
    milesAway: 1,
    bio:
        'Studying computer science. Looking for study partners for algorithms '
        'and system design.',
    interests: ['computer_science', 'algorithms', 'machine_learning'],
    photoAsset: AppAssets.avatarEmma,
    activeAgo: Duration.zero,
    likesBack: true,
  ),
  DemoPerson(
    id: 'david',
    name: 'David',
    age: 29,
    homeMode: 'trading',
    milesAway: 8,
    bio:
        "Markets enthusiast. Let's talk trends, charts and what we're "
        'watching this week.',
    interests: ['markets', 'charts', 'economics'],
    photoAsset: AppAssets.avatarDavid,
    activeAgo: Duration(days: 2),
  ),
  DemoPerson(
    id: 'zara',
    name: 'Zara',
    age: 26,
    homeMode: 'fitness',
    milesAway: 2,
    bio:
        'Early-morning runner and lifting partner looking for someone '
        'consistent and upbeat.',
    interests: ['strength', 'run_clubs', 'pilates'],
    photoAsset: AppAssets.avatarZara,
    activeAgo: Duration.zero,
  ),
];

DemoPerson? demoPersonById(String id) {
  for (final person in demoPeople) {
    if (person.id == id) return person;
  }
  return null;
}
