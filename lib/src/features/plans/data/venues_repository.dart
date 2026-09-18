import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo/demo_mode.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';
import '../../../core/network/api_envelope.dart';
import '../domain/venue.dart';
import 'demo_venues_repository.dart';

/// Places to meet, from Kinvo's list.
///
/// An interface because the demo shows the same screens without an account,
/// on [DemoVenuesRepository]. Failures are `ApiException`s.
abstract interface class VenuesRepository {
  /// Places near the user, nearest first: those of [category] when given,
  /// and suited to [mode] when given.
  Future<List<Venue>> searchVenues({VenueCategory? category, String? mode});

  /// Places near the user suited to the match [matchId]'s mode.
  Future<List<Venue>> suggestFor(String matchId);

  /// The places the user saved.
  Future<List<Venue>> fetchSaved();

  Future<void> save(String venueId);

  Future<void> unsave(String venueId);
}

/// [VenuesRepository] on the Kinvo API.
final class ApiVenuesRepository implements VenuesRepository {
  const ApiVenuesRepository(this._api);

  /// As many as the API gives at once.
  static const limit = 50;

  final ApiClient _api;

  @override
  Future<List<Venue>> searchVenues({VenueCategory? category, String? mode}) {
    return _api.get(
      '/venues',
      query: {
        'limit': '$limit',
        'category': ?category?.wireValue,
        'mode': ?mode,
      },
      decode: _readVenues,
    );
  }

  @override
  Future<List<Venue>> suggestFor(String matchId) {
    return _api.get(
      '/venues/suggest/${Uri.encodeComponent(matchId)}',
      decode: _readVenues,
    );
  }

  @override
  Future<List<Venue>> fetchSaved() {
    return _api.get('/venues/saved', decode: _readVenues);
  }

  @override
  Future<void> save(String venueId) {
    return _api.post(
      '/venues/${Uri.encodeComponent(venueId)}/save',
      decode: ApiClient.ignoreData,
    );
  }

  @override
  Future<void> unsave(String venueId) {
    return _api.delete(
      '/venues/${Uri.encodeComponent(venueId)}/save',
      decode: ApiClient.ignoreData,
    );
  }

  static List<Venue> _readVenues(JsonMap json) {
    if (json case {'venues': final List<Object?> venues}) {
      return [
        for (final venue in venues)
          if (venue is JsonMap) Venue.fromJson(venue),
      ];
    }
    throw const FormatException('Expected a list of venues.');
  }
}

/// The repository places come from: the demo's while exploring it, the API's
/// otherwise.
final venuesRepositoryProvider = Provider<VenuesRepository>((ref) {
  if (ref.watch(demoSessionProvider)) return DemoVenuesRepository();
  return ApiVenuesRepository(ref.watch(apiClientProvider));
});
