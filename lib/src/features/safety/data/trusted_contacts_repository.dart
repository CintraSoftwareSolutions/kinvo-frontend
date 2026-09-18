import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo/demo_mode.dart';
import '../../../core/location/geo_point.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_error_code.dart';
import '../../../core/network/api_exception.dart';
import '../domain/trusted_contact.dart';

/// The most trusted contacts the server keeps for one account.
const maxTrustedContacts = 5;

/// The user's trusted contacts, and alerting them.
///
/// An interface because the demo shows the same screens without an account,
/// on [DemoTrustedContactsRepository]. Failures are `ApiException`s.
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

/// Trusted contacts for the demo, kept in memory. Nobody is ever emailed.
final class DemoTrustedContactsRepository implements TrustedContactsRepository {
  DemoTrustedContactsRepository();

  final List<TrustedContact> _contacts = [
    const TrustedContact(
      id: 'demo-contact-1',
      name: 'Mum',
      phone: null,
      email: 'mum@example.com',
      relationship: 'Mum',
    ),
  ];
  int _added = 0;

  @override
  Future<List<TrustedContact>> fetchContacts() async => List.of(_contacts);

  @override
  Future<TrustedContact> addContact(ContactDetails details) async {
    if (_contacts.length >= maxTrustedContacts) {
      throw const ApiErrorException(
        code: ApiErrorCode.badRequest,
        message: 'You can have at most 5 trusted contacts.',
        statusCode: 400,
      );
    }
    final contact = _build('demo-contact-new-${++_added}', details);
    _contacts.add(contact);
    return contact;
  }

  @override
  Future<TrustedContact> updateContact(
    String contactId,
    ContactDetails details,
  ) async {
    final index = _contacts.indexWhere((contact) => contact.id == contactId);
    if (index < 0) throw _notFound;
    return _contacts[index] = _build(contactId, details);
  }

  @override
  Future<void> deleteContact(String contactId) async {
    _contacts.removeWhere((contact) => contact.id == contactId);
  }

  @override
  Future<EmergencyAlert> raiseEmergency({
    String? note,
    GeoPoint? location,
  }) async {
    return const EmergencyAlert(
      summary:
          'This is the demo, so nobody was emailed. With an account, your '
          'trusted contacts would be.',
      contacts: [],
    );
  }

  static TrustedContact _build(String id, ContactDetails details) {
    String? filled(String? value) {
      final trimmed = value?.trim() ?? '';
      return trimmed.isEmpty ? null : trimmed;
    }

    return TrustedContact(
      id: id,
      name: details.name.trim(),
      phone: filled(details.phone),
      email: filled(details.email),
      relationship: filled(details.relationship),
    );
  }

  static const _notFound = ApiErrorException(
    code: ApiErrorCode.notFound,
    message: 'We could not find that.',
    statusCode: 404,
  );
}

/// The repository trusted contacts use: the demo's while exploring it, the
/// API's otherwise.
final trustedContactsRepositoryProvider = Provider<TrustedContactsRepository>((
  ref,
) {
  if (ref.watch(demoSessionProvider)) return DemoTrustedContactsRepository();
  return ApiTrustedContactsRepository(ref.watch(apiClientProvider));
});
