import '../../../core/network/api_error_code.dart';
import '../../../core/network/api_exception.dart';
import '../domain/venue.dart';
import 'venues_repository.dart';

/// Places for the demo, kept in memory.
final class DemoVenuesRepository implements VenuesRepository {
  DemoVenuesRepository();

  static const samples = [
    Venue(
      id: 'demo-venue-1',
      name: 'Blue Bottle Coffee',
      category: VenueCategory.cafe,
      description: 'Slow-drip coffee and window seats.',
      address: '8 Kingly Street',
      city: 'London',
      rating: 4.8,
      priceLevel: 2,
      photoUrl: null,
      distanceMetres: 1300,
      isSaved: false,
    ),
    Venue(
      id: 'demo-venue-2',
      name: 'The Smith',
      category: VenueCategory.restaurant,
      description: 'Brasserie classics, open late.',
      address: '22 Charlotte Street',
      city: 'London',
      rating: 4.5,
      priceLevel: 3,
      photoUrl: null,
      distanceMetres: 1900,
      isSaved: false,
    ),
    Venue(
      id: 'demo-venue-3',
      name: 'Regent’s Park',
      category: VenueCategory.park,
      description: 'Rose gardens and a boating lake.',
      address: 'Chester Road',
      city: 'London',
      rating: 4.9,
      priceLevel: null,
      photoUrl: null,
      distanceMetres: 3400,
      isSaved: false,
    ),
    Venue(
      id: 'demo-venue-4',
      name: 'The British Library',
      category: VenueCategory.studySpot,
      description: 'Quiet reading rooms and a busy café.',
      address: '96 Euston Road',
      city: 'London',
      rating: 4.7,
      priceLevel: 1,
      photoUrl: null,
      distanceMetres: 2600,
      isSaved: false,
    ),
  ];

  final Set<String> _saved = {};

  @override
  Future<List<Venue>> searchVenues({
    VenueCategory? category,
    String? mode,
  }) async {
    return [
      for (final venue in samples)
        if (category == null || venue.category == category) _withSaved(venue),
    ];
  }

  @override
  Future<List<Venue>> suggestFor(String matchId) => searchVenues();

  @override
  Future<List<Venue>> fetchSaved() async {
    return [
      for (final venue in samples)
        if (_saved.contains(venue.id)) _withSaved(venue),
    ];
  }

  @override
  Future<void> save(String venueId) async {
    _requireKnown(venueId);
    _saved.add(venueId);
  }

  @override
  Future<void> unsave(String venueId) async {
    _requireKnown(venueId);
    _saved.remove(venueId);
  }

  Venue _withSaved(Venue venue) {
    return venue.copyWith(isSaved: _saved.contains(venue.id));
  }

  static void _requireKnown(String venueId) {
    if (samples.any((venue) => venue.id == venueId)) return;
    throw const ApiErrorException(
      code: ApiErrorCode.notFound,
      message: 'That venue is not available.',
      statusCode: 404,
    );
  }
}
