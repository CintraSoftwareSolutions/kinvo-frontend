import 'package:flutter/foundation.dart';

import '../../../core/network/api_envelope.dart';
import '../../profile/domain/person_photos.dart';
import '../../profile/domain/user_summary.dart';

/// One person in today's deck for a mode.
@immutable
final class DeckCard {
  const DeckCard({
    required this.entryId,
    required this.position,
    required this.distanceMetres,
    required this.user,
    required this.photos,
    required this.bio,
    required this.interestSlugs,
  });

  /// Reads one item of `GET /discovery/{mode}/deck`.
  factory DeckCard.fromJson(JsonMap json) {
    if (json case {
      'entry_id': final String entryId,
      'position': final int position,
      'distance_metres': final num? distanceMetres,
      'user': final JsonMap user,
      'bio': final String? bio,
      'interests': final List<Object?> interests,
    } when entryId.isNotEmpty) {
      return DeckCard(
        entryId: entryId,
        position: position,
        distanceMetres: distanceMetres?.toDouble(),
        user: UserSummary.fromJson(user),
        photos: PersonPhotoRef.listFromJson(json['photos']),
        bio: bio,
        interestSlugs: interests.whereType<String>().toList(growable: false),
      );
    }
    throw const FormatException(
      'Expected a deck card with entry_id, position, distance_metres, user, '
      'bio and interests.',
    );
  }

  /// The card's place in the deck, unique within a day.
  final String entryId;
  final int position;

  /// How far away they are, or `null` when either person has no location.
  final double? distanceMetres;

  final UserSummary user;

  /// Their approved photos, in the order they arranged them. Empty for
  /// someone with none, and the first is the one on [UserSummary.photoUrl].
  final List<PersonPhotoRef> photos;

  final String? bio;

  /// Their interests, by slug. Labels come from `GET /config`.
  final List<String> interestSlugs;
}
