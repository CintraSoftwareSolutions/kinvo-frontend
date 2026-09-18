import 'package:flutter/foundation.dart';

import '../../../core/network/api_envelope.dart';

/// Someone else, in the compact shape every list in the API shares: deck
/// cards, matches and likes. Enough to draw a card or a row without asking
/// the server for more.
@immutable
final class UserSummary {
  const UserSummary({
    required this.id,
    required this.displayName,
    required this.age,
    required this.photoUrl,
    required this.isVerified,
    required this.isPremium,
    required this.isOnline,
    required this.lastActiveAt,
  });

  factory UserSummary.fromJson(JsonMap json) {
    if (json case {
      'id': final String id,
      'display_name': final String displayName,
      'age': final int? age,
      'primary_photo_url': final String? photoUrl,
      'is_verified': final bool isVerified,
      'is_premium': final bool isPremium,
      'is_online': final bool isOnline,
      'last_active_at': final String? lastActiveAt,
    } when id.isNotEmpty) {
      final lastActive = lastActiveAt == null
          ? null
          : DateTime.tryParse(lastActiveAt);
      if (lastActiveAt == null || lastActive != null) {
        return UserSummary(
          id: id,
          displayName: displayName,
          age: age,
          photoUrl: photoUrl == null ? null : Uri.tryParse(photoUrl),
          isVerified: isVerified,
          isPremium: isPremium,
          isOnline: isOnline,
          lastActiveAt: lastActive,
        );
      }
    }
    throw const FormatException(
      'Expected a user with id, display_name, age, primary_photo_url, '
      'is_verified, is_premium, is_online and last_active_at.',
    );
  }

  final String id;
  final String displayName;

  /// Worked out from the date of birth. Only accounts that haven't finished
  /// onboarding lack one, and those never appear in a deck.
  final int? age;

  /// Their main photo. The link expires, and every read gives a new one.
  final Uri? photoUrl;

  /// Has proved who they are.
  final bool isVerified;

  /// Has a paid plan.
  final bool isPremium;

  /// Connected right now. Lists that don't look this up, such as decks,
  /// always say false, so treat false as "not known to be online".
  final bool isOnline;

  /// When they were last around, or `null` when they don't show it.
  final DateTime? lastActiveAt;

  /// This user, having come online or gone offline, or having started or
  /// stopped showing when they're active.
  UserSummary withPresence({
    required bool isOnline,
    required DateTime? lastActiveAt,
  }) {
    return UserSummary(
      id: id,
      displayName: displayName,
      age: age,
      photoUrl: photoUrl,
      isVerified: isVerified,
      isPremium: isPremium,
      isOnline: isOnline,
      lastActiveAt: lastActiveAt,
    );
  }
}
