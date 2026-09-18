import '../../profile/domain/user_summary.dart';

/// When someone was last around, as a card shows it: "Online now",
/// "Active today" or "Active this week". `null` when longer ago than that,
/// or when they don't show it.
///
/// Deliberately coarse. A precise "active 12 minutes ago" on every card tells
/// anyone watching exactly when someone opens the app.
String? activityLabel(UserSummary user, {required DateTime now}) {
  if (user.isOnline) return 'Online now';
  final lastActiveAt = user.lastActiveAt;
  if (lastActiveAt == null) return null;
  final since = now.difference(lastActiveAt);
  if (since < const Duration(hours: 24)) return 'Active today';
  if (since < const Duration(days: 7)) return 'Active this week';
  return null;
}

/// A value from the API, such as `have_children`, as words: "Have children".
String humanise(String value) {
  final words = value.replaceAll('_', ' ').trim();
  if (words.isEmpty) return words;
  return words[0].toUpperCase() + words.substring(1);
}
