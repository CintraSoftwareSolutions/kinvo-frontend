import 'package:flutter/painting.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/config/server_config.dart';
import '../../../core/theme/app_colors.dart';

/// A mode's colours, by its name in the API: [primary] for its buttons and
/// badges, [soft] behind them. A mode added after this version of the app
/// gets the app's own colours.
({Color primary, Color soft}) modeColors(String mode) {
  return switch (mode) {
    'dating' => (
      primary: const Color(0xFFEF4458),
      soft: const Color(0xFFFFE4E8),
    ),
    'study_buddy' => (
      primary: const Color(0xFF2563EB),
      soft: const Color(0xFFDBEAFE),
    ),
    'networking' => (
      primary: const Color(0xFF6366F1),
      soft: const Color(0xFFE0E7FF),
    ),
    'trading' => (
      primary: const Color(0xFF10B981),
      soft: const Color(0xFFD1FAE5),
    ),
    'foodie' => (
      primary: const Color(0xFFF59E0B),
      soft: const Color(0xFFFEF3C7),
    ),
    'cuddle' => (
      primary: const Color(0xFFEC4899),
      soft: const Color(0xFFFCE7F0),
    ),
    'pet_dates' => (
      primary: const Color(0xFFF97316),
      soft: const Color(0xFFFFEDD5),
    ),
    'fitness' => (
      primary: const Color(0xFF14B8A6),
      soft: const Color(0xFFCCFBF1),
    ),
    _ => (primary: AppColors.purple, soft: AppColors.purpleSoft),
  };
}

/// The icon for a mode, by its name in the API. A mode added after this
/// version of the app gets a general icon.
String modeIconAsset(String mode) {
  return switch (mode) {
    'dating' => AppAssets.heartFill,
    'study_buddy' => AppAssets.modeStudy,
    'networking' => AppAssets.modeNetworking,
    'trading' => AppAssets.modeTrading,
    'foodie' => AppAssets.modeFoodie,
    'cuddle' => AppAssets.modeCuddle,
    'pet_dates' => AppAssets.modePet,
    'fitness' => AppAssets.modeFitness,
    _ => AppAssets.sparkle,
  };
}

/// The heading for a group of interests, by its category in the API. A
/// category added after this version of the app is named from its API name.
String interestCategoryLabel(String category) {
  return switch (category) {
    'general' => 'General',
    'comfort' => 'Comfort',
    'fitness' => 'Fitness',
    'food' => 'Food & drink',
    'pets' => 'Pets',
    'professional' => 'Work',
    'subject' => 'Study',
    'trading_interest' => 'Markets',
    _ => _sentenceCase(category.replaceAll('_', ' ')),
  };
}

String _sentenceCase(String words) {
  final trimmed = words.trim();
  if (trimmed.isEmpty) return 'Other';
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}

/// [interests] grouped by category, in the server's order, except that
/// general interests come first because they suit everyone.
List<(String, List<InterestOption>)> groupInterestsByCategory(
  List<InterestOption> interests,
) {
  final groups = <String, List<InterestOption>>{};
  for (final interest in interests) {
    (groups[interest.category] ??= []).add(interest);
  }
  return [
    for (final MapEntry(key: category, value: options) in groups.entries)
      if (category == 'general') (category, options),
    for (final MapEntry(key: category, value: options) in groups.entries)
      if (category != 'general') (category, options),
  ];
}
