import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
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

/// How a plan's state reads on its pill, and its colours.
typedef PlanBadge = ({String label, Color background, Color foreground});

/// The pill a plan shows, at [now].
PlanBadge planBadge(Plan plan, DateTime now) {
  const green = (background: Color(0xFFD1FAE5), foreground: Color(0xFF047857));
  const orange = (background: Color(0xFFFFEDD5), foreground: Color(0xFFC2410C));
  const purple = (
    background: AppColors.purpleSoft,
    foreground: AppColors.purple,
  );
  const grey = (
    background: AppColors.surfaceSoft,
    foreground: AppColors.textSecondary,
  );
  const red = (background: Color(0xFFFFE4E8), foreground: Color(0xFFBE123C));

  final started = plan.hasStarted(now);
  final (label, colors) = switch (plan.status) {
    PlanStatus.draft => ('Draft', grey),
    PlanStatus.proposed when started => ('Time passed', grey),
    PlanStatus.proposed when plan.awaitingMyResponse => ('Your answer', purple),
    PlanStatus.proposed => ('Waiting', orange),
    PlanStatus.confirmed when started => ('Past', grey),
    PlanStatus.confirmed => ('Confirmed', green),
    PlanStatus.declined => ('Declined', red),
    PlanStatus.cancelled => ('Cancelled', red),
    PlanStatus.completed => ('Past', grey),
    PlanStatus.unknown => ('Plan', grey),
  };
  return (
    label: label,
    background: colors.background,
    foreground: colors.foreground,
  );
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
