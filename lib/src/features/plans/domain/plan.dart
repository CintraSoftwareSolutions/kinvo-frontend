import '../../../core/assets/app_assets.dart';

enum PlanStatus { upcoming, pending, completed, cancelled }

class Plan {
  const Plan({
    required this.id,
    required this.title,
    required this.venue,
    required this.dateTime,
    required this.status,
    required this.attendeeAvatar,
    required this.attendeeName,
    required this.modeColor,
  });

  final String id;
  final String title;
  final String venue;
  final String dateTime;
  final PlanStatus status;
  final String attendeeAvatar;
  final String attendeeName;
  final int modeColor;
}

abstract final class SamplePlans {
  static const _dating = 0xFFEF4458;
  static const _study = 0xFF2563EB;
  static const _networking = 0xFF6366F1;

  static const all = <Plan>[
    Plan(
      id: 'p1',
      title: 'Coffee',
      venue: 'Blue Bottle Coffee',
      dateTime: 'Saturday | 2:00 PM',
      status: PlanStatus.upcoming,
      attendeeAvatar: AppAssets.avatarSarah,
      attendeeName: 'Sarah',
      modeColor: _dating,
    ),
    Plan(
      id: 'p2',
      title: 'Study Session',
      venue: 'NYU Library',
      dateTime: 'Saturday | 2:00 PM',
      status: PlanStatus.pending,
      attendeeAvatar: AppAssets.avatarEmma,
      attendeeName: 'Emma',
      modeColor: _study,
    ),
    Plan(
      id: 'p3',
      title: 'Founder Breakfast',
      venue: 'Devocion Williamsburg',
      dateTime: 'Saturday | 2:00 PM',
      status: PlanStatus.upcoming,
      attendeeAvatar: AppAssets.avatarMarcus,
      attendeeName: 'Marcus',
      modeColor: _networking,
    ),
    Plan(
      id: 'p4',
      title: 'Riverside Walk',
      venue: 'Brooklyn Bridge Park',
      dateTime: 'Saturday | 2:00 PM',
      status: PlanStatus.completed,
      attendeeAvatar: AppAssets.avatarSarah,
      attendeeName: 'Sarah',
      modeColor: _dating,
    ),
    Plan(
      id: 'p5',
      title: 'System Design Jam',
      venue: 'The Commons Study Lounge',
      dateTime: 'Saturday | 2:00 PM',
      status: PlanStatus.cancelled,
      attendeeAvatar: AppAssets.avatarEmma,
      attendeeName: 'Emma',
      modeColor: _study,
    ),
    Plan(
      id: 'p6',
      title: 'Coffee and Career Notes',
      venue: 'Think Coffee SoHo',
      dateTime: 'Saturday | 2:00 PM',
      status: PlanStatus.pending,
      attendeeAvatar: AppAssets.avatarMarcus,
      attendeeName: 'Marcus',
      modeColor: _networking,
    ),
  ];
}

class Venue {
  const Venue({
    required this.id,
    required this.name,
    required this.type,
    required this.image,
    required this.distanceMiles,
    required this.savedCount,
    required this.rating,
  });

  final String id;
  final String name;
  final String type;
  final String image;
  final double distanceMiles;
  final int savedCount;
  final double rating;
}

abstract final class SampleVenues {
  static const all = <Venue>[
    Venue(
      id: 'v1',
      name: 'Blue Bottle Coffee',
      type: 'Cafe',
      image: AppAssets.venueBlueBottle,
      distanceMiles: 0.8,
      savedCount: 24,
      rating: 4.8,
    ),
    Venue(
      id: 'v2',
      name: 'The Smith',
      type: 'Restaurant',
      image: AppAssets.venueSmith,
      distanceMiles: 1.2,
      savedCount: 156,
      rating: 4.5,
    ),
    Venue(
      id: 'v3',
      name: 'Central Park',
      type: 'Park',
      image: AppAssets.venueCentralPark,
      distanceMiles: 2.1,
      savedCount: 89,
      rating: 4.9,
    ),
    Venue(
      id: 'v4',
      name: 'Equinox Fitness',
      type: 'Gym',
      image: AppAssets.venueEquinox,
      distanceMiles: 0.6,
      savedCount: 124,
      rating: 4.4,
    ),
  ];
}
