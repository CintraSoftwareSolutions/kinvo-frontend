import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/geo_point.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';
import '../../../core/network/api_envelope.dart';
import '../domain/trusted_contact.dart';

/// The most trusted contacts the server keeps for one account.
const maxTrustedContacts = 5;

/// The user's trusted contacts, and alerting them.
///
/// Failures are `ApiException`s.
abstract interface class TrustedContactsRepository {
  Future<List<TrustedContact>> fetchContacts();

  Future<TrustedContact> addContact(ContactDetails details);

  Future<TrustedContact> updateContact(
    String contactId,
    ContactDetails details,
  );

  Future<void> deleteContact(String contactId);

  /// Raises an emergency: every trusted contact with an email address is
  /// emailed, with roughly where the user is when [location] is known.
  Future<EmergencyAlert> raiseEmergency({String? note, GeoPoint? location});
}

/// [TrustedContactsRepository] on the Kinvo API.
final class ApiTrustedContactsRepository implements TrustedContactsRepository {
  const ApiTrustedContactsRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<TrustedContact>> fetchContacts() {
    return _api.get('/safety/contacts', decode: _readContacts);
  }

  @override
  Future<TrustedContact> addContact(ContactDetails details) {
    return _api.post(
      '/safety/contacts',
      body: {
        'name': details.name.trim(),
        'phone': ?_filled(details.phone),
        'email': ?_filled(details.email),
        'relationship': ?_filled(details.relationship),
      },
      decode: TrustedContact.fromJson,
    );
  }

  @override
  Future<TrustedContact> updateContact(
    String contactId,
    ContactDetails details,
  ) {
    // Every field is sent, an empty one clearing what was there.
    return _api.patch(
      '/safety/contacts/${Uri.encodeComponent(contactId)}',
      body: {
        'name': details.name.trim(),
        'phone': details.phone?.trim() ?? '',
        'email': details.email?.trim() ?? '',
        'relationship': details.relationship?.trim() ?? '',
      },
      decode: TrustedContact.fromJson,
    );
  }

  @override
  Future<void> deleteContact(String contactId) {
    return _api.delete(
      '/safety/contacts/${Uri.encodeComponent(contactId)}',
      decode: ApiClient.ignoreData,
    );
  }

  @override
  Future<EmergencyAlert> raiseEmergency({String? note, GeoPoint? location}) {
    return _api.post(
      '/safety/emergency',
      body: {
        'note': ?_filled(note),
        if (location != null) ...{
          'latitude': location.latitude,
          'longitude': location.longitude,
        },
        // So times in the emails read as the user's own.
        'utc_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
      },
      decode: EmergencyAlert.fromJson,
    );
  }

  static String? _filled(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  static List<TrustedContact> _readContacts(JsonMap json) {
    if (json case {'contacts': final List<Object?> contacts}) {
      return [
        for (final contact in contacts)
          if (contact is JsonMap) TrustedContact.fromJson(contact),
      ];
    }
    throw const FormatException('Expected a list of contacts.');
  }
}

/// The repository trusted contacts use.
final trustedContactsRepositoryProvider = Provider<TrustedContactsRepository>((
  ref,
) {
  return ApiTrustedContactsRepository(ref.watch(apiClientProvider));
});
