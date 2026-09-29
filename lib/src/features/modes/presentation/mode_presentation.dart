import '../../../core/assets/app_assets.dart';
import '../../../core/config/server_config.dart';
import '../../../core/theme/kinvo_colors.dart';

/// A mode's hue, by its name in the API. A mode added after this version of
/// the app gets the app's own.
Hue modeHue(String mode) {
  return switch (mode) {
    'dating' => Hue.red,
    'study_buddy' => Hue.blue,
    'networking' => Hue.indigo,
    'trading' => Hue.green,
    'foodie' => Hue.amber,
    'cuddle' => Hue.pink,
    'pet_dates' => Hue.orange,
    'fitness' => Hue.teal,
    _ => Hue.purple,
  };
}

/// Modes' colours in a palette.
extension ModeColors on KinvoColors {
  /// [mode]'s colours, by its name in the API: `color` for its buttons and
  /// badges, `soft` behind them.
  Tint mode(String mode) => tint(modeHue(mode));
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
