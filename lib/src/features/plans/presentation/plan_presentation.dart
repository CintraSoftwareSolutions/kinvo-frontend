import 'package:flutter/material.dart';

import '../../../core/theme/kinvo_colors.dart';
import '../domain/plan.dart';
import '../domain/venue.dart';

/// When a plan starts, as a line of text: "Sat, Sep 20 · 7:00 PM".
String planTime(BuildContext context, DateTime? scheduledAt) {
  if (scheduledAt == null) return 'No time set yet';
  final localizations = MaterialLocalizations.of(context);
  final local = scheduledAt.toLocal();
  final day = localizations.formatMediumDate(local);
  final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local));
  return '$day · $time';
}

/// How long a plan lasts: "45 min", "1 hour", "1 hour 30 min".
String durationLabel(int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  final hourPart = switch (hours) {
    0 => '',
    1 => '1 hour',
    _ => '$hours hours',
  };
  if (rest == 0) return hourPart;
  return hourPart.isEmpty ? '$rest min' : '$hourPart $rest min';
}

/// How a plan's state reads on its pill: its words, and the hue it's drawn
/// in. No hue for a plan that's over, or that hasn't been sent: those are
/// grey.
typedef PlanBadge = ({String label, Hue? hue});

/// The pill a plan shows, at [now].
PlanBadge planBadge(Plan plan, DateTime now) {
  final started = plan.hasStarted(now);
  final (label, hue) = switch (plan.status) {
    PlanStatus.draft => ('Draft', null),
    PlanStatus.proposed when started => ('Time passed', null),
    PlanStatus.proposed when plan.awaitingMyResponse => (
      'Your answer',
      Hue.purple,
    ),
    PlanStatus.proposed => ('Waiting', Hue.orange),
    PlanStatus.confirmed when started => ('Past', null),
    PlanStatus.confirmed => ('Confirmed', Hue.green),
    PlanStatus.declined => ('Declined', Hue.red),
    PlanStatus.cancelled => ('Cancelled', Hue.red),
    PlanStatus.completed => ('Past', null),
    PlanStatus.unknown => ('Plan', null),
  };
  return (label: label, hue: hue);
}

/// An icon for a kind of place.
IconData venueIcon(VenueCategory? category) {
  return switch (category) {
    VenueCategory.cafe => Icons.local_cafe_outlined,
    VenueCategory.restaurant => Icons.restaurant_outlined,
    VenueCategory.park => Icons.park_outlined,
    VenueCategory.gym => Icons.fitness_center_outlined,
    VenueCategory.studySpot => Icons.menu_book_outlined,
    VenueCategory.petFriendly => Icons.pets_outlined,
    VenueCategory.romantic => Icons.favorite_border_rounded,
    VenueCategory.healthConscious => Icons.eco_outlined,
    VenueCategory.unknown || null => Icons.place_outlined,
  };
}
