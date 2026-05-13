import 'package:flutter/material.dart';

import '../../../core/assets/app_assets.dart';

enum DiscoverModeId {
  cuddle,
  dating,
  foodie,
  networking,
  petDates,
  studyBuddy,
  trading,
  fitness,
}

enum ProfileStatusKind { online, recent, minutesAgo, hoursAgo }

class ProfileStatus {
  const ProfileStatus({required this.kind, required this.label});

  final ProfileStatusKind kind;
  final String label;
}

class DiscoverProfile {
  const DiscoverProfile({
    required this.name,
    required this.age,
    required this.milesAway,
    required this.bio,
    required this.interests,
    required this.imageAsset,
    this.imageFallbackColor,
    required this.status,
    this.isVerified = true,
    this.isPremium = false,
  });

  final String name;
  final int age;
  final int milesAway;
  final String bio;
  final List<String> interests;
  final String? imageAsset;
  final Color? imageFallbackColor;
  final ProfileStatus status;
  final bool isVerified;
  final bool isPremium;
}

class DiscoverMode {
  const DiscoverMode({
    required this.id,
    required this.label,
    required this.sessionFocus,
    required this.modeIcon,
    required this.actionLabel,
    required this.actionSubtitle,
    required this.actionIcon,
    required this.summaryCta,
    required this.emptyStateMessage,
    required this.primary,
    required this.primarySoft,
    required this.profile,
  });

  final DiscoverModeId id;
  final String label;
  final String sessionFocus;
  final String modeIcon;
  final String actionLabel;
  final String actionSubtitle;
  final String actionIcon;
  final String summaryCta;
  final String emptyStateMessage;
  final Color primary;
  final Color primarySoft;
  final DiscoverProfile profile;
}

abstract final class DiscoverModes {
  static const cuddle = DiscoverMode(
    id: DiscoverModeId.cuddle,
    label: 'Cuddle',
    sessionFocus: 'Warmth focused',
    modeIcon: AppAssets.modeCuddle,
    actionLabel: 'Cozy',
    actionSubtitle: 'Warmth',
    actionIcon: AppAssets.modeCuddle,
    summaryCta: 'Send a cozy hello',
    emptyStateMessage:
        'Try widening your filters or bring back the last cozy match you passed.',
    primary: Color(0xFFEC4899),
    primarySoft: Color(0xFFFCE7F0),
    profile: DiscoverProfile(
      name: 'Maya',
      age: 30,
      milesAway: 4,
      bio:
          'Soft-spoken creative who loves movie nights, candleli corners, and emotionally safe check-ins...',
      interests: ['Cozy Nights', 'Journaling', 'Tea', '+2 more'],
      imageAsset: AppAssets.avatarMaya,
      status: ProfileStatus(
        kind: ProfileStatusKind.minutesAgo,
        label: '41 minutes ago',
      ),
    ),
  );

  static const dating = DiscoverMode(
    id: DiscoverModeId.dating,
    label: 'Dating',
    sessionFocus: 'Match focused',
    modeIcon: AppAssets.heartFill,
    actionLabel: 'Like',
    actionSubtitle: 'Match',
    actionIcon: AppAssets.heartFill,
    summaryCta: 'Suggest a date',
    emptyStateMessage:
        'Try widening your filters or bring back the last person you passed.',
    primary: Color(0xFFEF4458),
    primarySoft: Color(0xFFFFE4E8),
    profile: DiscoverProfile(
      name: 'Sarah',
      age: 28,
      milesAway: 2,
      bio:
          'Love exploring new coffee shops and weekend hikes Looking for someone who values deep convers..',
      interests: ['Coffee', 'Hiking', 'Photography', '+2 more'],
      imageAsset: AppAssets.avatarSarah,
      status: ProfileStatus(
        kind: ProfileStatusKind.online,
        label: 'Online now',
      ),
    ),
  );

  static const foodie = DiscoverMode(
    id: DiscoverModeId.foodie,
    label: 'Foodie',
    sessionFocus: 'Table focused',
    modeIcon: AppAssets.modeFoodie,
    actionLabel: 'Taste',
    actionSubtitle: 'Table',
    actionIcon: AppAssets.modeFoodie,
    summaryCta: 'Pick a place to eat',
    emptyStateMessage:
        'Try widening your filters or bring back the last foodie you passed.',
    primary: Color(0xFFF59E0B),
    primarySoft: Color(0xFFFEF3C7),
    profile: DiscoverProfile(
      name: 'Olivia',
      age: 27,
      milesAway: 3,
      bio:
          'Foodie on a mission to try every cuisine in the city. Wh wants to be my dining partner?',
      interests: ['Food', 'Cooking', 'Wine', 'Travel', 'Photography'],
      imageAsset: AppAssets.avatarOlivia,
      status: ProfileStatus(
        kind: ProfileStatusKind.online,
        label: 'Online now',
      ),
      isPremium: true,
    ),
  );

  static const networking = DiscoverMode(
    id: DiscoverModeId.networking,
    label: 'Networking',
    sessionFocus: 'Intro focused',
    modeIcon: AppAssets.modeNetworking,
    actionLabel: 'Connect',
    actionSubtitle: 'Intro',
    actionIcon: AppAssets.modeNetworking,
    summaryCta: 'Schedule an intro',
    emptyStateMessage:
        'Try widening your filters or bring back the last intro you passed.',
    primary: Color(0xFF6366F1),
    primarySoft: Color(0xFFE0E7FF),
    profile: DiscoverProfile(
      name: 'Marcus',
      age: 32,
      milesAway: 5,
      bio:
          'Software engineer passionate about AI and startups Always up for networking over coffee.',
      interests: ['Tech', 'AI', 'Startups', '+2 more'],
      imageAsset: null,
      imageFallbackColor: Color(0xFF4F46E5),
      status: ProfileStatus(
        kind: ProfileStatusKind.hoursAgo,
        label: '2 hours ago',
      ),
      isPremium: true,
    ),
  );

  static const petDates = DiscoverMode(
    id: DiscoverModeId.petDates,
    label: 'Pet Dates',
    sessionFocus: 'Playdate focused',
    modeIcon: AppAssets.modePet,
    actionLabel: 'Paw',
    actionSubtitle: 'Playdate',
    actionIcon: AppAssets.modePet,
    summaryCta: 'Plan a playdate',
    emptyStateMessage:
        'Try widening your filters or bring back the last pet pal you passed.',
    primary: Color(0xFFF97316),
    primarySoft: Color(0xFFFFEDD5),
    profile: DiscoverProfile(
      name: 'Noah',
      age: 31,
      milesAway: 6,
      bio:
          'Dog dad looking for pet-friendly parks, new walkin trails, and easygoing people who love anim..',
      interests: ['Dog Parks', 'Pet Cafes', 'Weekend Walks', '+2 more'],
      imageAsset: AppAssets.avatarNoah,
      status: ProfileStatus(
        kind: ProfileStatusKind.online,
        label: 'Online now',
      ),
      isPremium: true,
    ),
  );

  static const studyBuddy = DiscoverMode(
    id: DiscoverModeId.studyBuddy,
    label: 'Study Buddy',
    sessionFocus: 'Invite focused',
    modeIcon: AppAssets.modeStudy,
    actionLabel: 'Study',
    actionSubtitle: 'Invite',
    actionIcon: AppAssets.modeStudy,
    summaryCta: 'Set up a study session',
    emptyStateMessage:
        'Try widening your filters or bring back the last study buddy you passed.',
    primary: Color(0xFF2563EB),
    primarySoft: Color(0xFFDBEAFE),
    profile: DiscoverProfile(
      name: 'Emma',
      age: 25,
      milesAway: 1,
      bio:
          'Studying computer science at NYU. Looking for stud partners for algorithms and system design.',
      interests: ['Computer Science', 'Algorithms', 'Machine Learning', '+2 more'],
      imageAsset: AppAssets.avatarEmma,
      status: ProfileStatus(
        kind: ProfileStatusKind.online,
        label: 'Online now',
      ),
    ),
  );

  static const trading = DiscoverMode(
    id: DiscoverModeId.trading,
    label: 'Trading',
    sessionFocus: 'Signal focused',
    modeIcon: AppAssets.modeTrading,
    actionLabel: 'Trade',
    actionSubtitle: 'Signal',
    actionIcon: AppAssets.modeTrading,
    summaryCta: 'Share a chart',
    emptyStateMessage:
        'Try widening your filters or bring back the last trader you passed.',
    primary: Color(0xFF10B981),
    primarySoft: Color(0xFFD1FAE5),
    profile: DiscoverProfile(
      name: 'David',
      age: 29,
      milesAway: 8,
      bio:
          "Crypto trader and blockchain enthusiast. Let's discus market trends and trading strategies.",
      interests: ['Crypto', 'Trading', 'DeFi', '+2 more'],
      imageAsset: AppAssets.avatarDavid,
      status: ProfileStatus(
        kind: ProfileStatusKind.recent,
        label: 'Seen Recently',
      ),
    ),
  );

  static const fitness = DiscoverMode(
    id: DiscoverModeId.fitness,
    label: 'Fitness',
    sessionFocus: 'Workout focused',
    modeIcon: AppAssets.modeFitness,
    actionLabel: 'Train',
    actionSubtitle: 'Workout',
    actionIcon: AppAssets.modeFitness,
    summaryCta: 'Plan a workout',
    emptyStateMessage:
        'Try widening your filters or bring back the last workout partner you passed.',
    primary: Color(0xFF14B8A6),
    primarySoft: Color(0xFFCCFBF1),
    profile: DiscoverProfile(
      name: 'Zara',
      age: 26,
      milesAway: 2,
      bio:
          'Early-morning runner and lifting partner looking fo someone consistent, upbeat, and serious a..',
      interests: ['Strength', 'Run Clubs', 'Pilates', '+2 more'],
      imageAsset: AppAssets.avatarZara,
      imageFallbackColor: Color(0xFF0F766E),
      status: ProfileStatus(
        kind: ProfileStatusKind.online,
        label: 'Online now',
      ),
    ),
  );

  static const all = <DiscoverMode>[
    cuddle,
    dating,
    foodie,
    networking,
    petDates,
    studyBuddy,
    trading,
    fitness,
  ];

  static DiscoverMode byId(DiscoverModeId id) =>
      all.firstWhere((m) => m.id == id);
}
