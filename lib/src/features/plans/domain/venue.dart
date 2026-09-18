import 'package:flutter/foundation.dart';

import '../../../core/network/api_envelope.dart';

/// The kinds of place Kinvo lists.
enum VenueCategory {
  cafe('cafe', 'Café'),
  restaurant('restaurant', 'Restaurant'),
  park('park', 'Park'),
  gym('gym', 'Gym'),
  studySpot('study_spot', 'Study spot'),
  petFriendly('pet_friendly', 'Pet friendly'),
  romantic('romantic', 'Romantic'),
  healthConscious('health_conscious', 'Healthy'),

  /// A kind added to the server after this version of the app.
  unknown('', 'Place');

  const VenueCategory(this.wireValue, this.label);

  /// Its name in the API.
  final String wireValue;

  final String label;

  /// Every kind a search can ask for.
  static List<VenueCategory> get searchable {
    return [
      for (final category in values)
        if (category != unknown) category,
    ];
  }

  static VenueCategory fromWireValue(String value) {
    for (final category in values) {
      if (category != unknown && category.wireValue == value) return category;
    }
    return unknown;
  }
}

/// A place from Kinvo's list, somewhere to meet.
@immutable
final class Venue {
  const Venue({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.address,
    required this.city,
    required this.rating,
    required this.priceLevel,
    required this.photoUrl,
    required this.distanceMetres,
    required this.isSaved,
  });

  /// Reads one venue, as the venues endpoints return it.
  factory Venue.fromJson(JsonMap json) {
    if (json case {
      'id': final String id,
      'name': final String name,
      'category': final String category,
      'description': final String? description,
      'address': final String? address,
      'city': final String? city,
      'rating': final num? rating,
      'price_level': final int? priceLevel,
      'photo_url': final String? photoUrl,
      'distance_metres': final num? distanceMetres,
      'is_saved': final bool isSaved,
    } when id.isNotEmpty) {
      return Venue(
        id: id,
        name: name,
        category: VenueCategory.fromWireValue(category),
        description: description,
        address: address,
        city: city,
        rating: rating?.toDouble(),
        priceLevel: priceLevel,
        photoUrl: photoUrl == null ? null : Uri.tryParse(photoUrl),
        distanceMetres: distanceMetres?.toDouble(),
        isSaved: isSaved,
      );
    }
    throw const FormatException(
      'Expected a venue with id, name, category, description, address, city, '
      'rating, price_level, photo_url, distance_metres and is_saved.',
    );
  }

  final String id;
  final String name;
  final VenueCategory category;
  final String? description;
  final String? address;
  final String? city;

  /// Out of 5.
  final double? rating;

  /// From 1, cheap, to 4.
  final int? priceLevel;

  final Uri? photoUrl;

  /// How far it is from the user. Missing when either location isn't known.
  final double? distanceMetres;

  /// Whether the user saved it to their list.
  final bool isSaved;

  Venue copyWith({required bool isSaved}) {
    return Venue(
      id: id,
      name: name,
      category: category,
      description: description,
      address: address,
      city: city,
      rating: rating,
      priceLevel: priceLevel,
      photoUrl: photoUrl,
      distanceMetres: distanceMetres,
      isSaved: isSaved,
    );
  }
}
