import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/location/geo_point.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/network/api_error_code.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/trusted_contacts_repository.dart';
import '../../domain/trusted_contact.dart';

/// The user's trusted contacts, oldest first.
final trustedContactsProvider =
    AsyncNotifierProvider.autoDispose<
      TrustedContactsController,
      List<TrustedContact>
    >(TrustedContactsController.new);

/// How saving a trusted contact went.
@immutable
sealed class ContactSaveOutcome {
  const ContactSaveOutcome();
}

final class ContactSaved extends ContactSaveOutcome {
  const ContactSaved(this.contact);

  final TrustedContact contact;
}

final class ContactRefused extends ContactSaveOutcome {
  const ContactRefused(this.message, {this.fieldErrors = const {}});

  final String message;

  /// The server's messages for each field it refused, keyed as the API names
  /// them, such as `email`.
  final Map<String, List<String>> fieldErrors;
}

class TrustedContactsController extends AsyncNotifier<List<TrustedContact>> {
  TrustedContactsRepository get _repository {
    return ref.read(trustedContactsRepositoryProvider);
  }

  @override
  Future<List<TrustedContact>> build() {
    return ref.watch(trustedContactsRepositoryProvider).fetchContacts();
  }

  /// Adds a contact, or changes the one with [contactId].
  Future<ContactSaveOutcome> save(
    ContactDetails details, {
    String? contactId,
  }) async {
    try {
      final saved = contactId == null
          ? await _repository.addContact(details)
          : await _repository.updateContact(contactId, details);
      if (ref.mounted) {
        _update((contacts) {
          final replaced = [
            for (final contact in contacts)
              contact.id == saved.id ? saved : contact,
          ];
          return contactId == null ? [...contacts, saved] : replaced;
        });
      }
      return ContactSaved(saved);
    } on ApiException catch (error) {
      return ContactRefused(
        error.message,
        fieldErrors: error is ApiErrorException ? error.fieldErrors : const {},
      );
    }
  }

  /// Removes [contact]. Returns why it failed, or `null` once it's gone.
  Future<String?> delete(TrustedContact contact) async {
    try {
      await _repository.deleteContact(contact.id);
    } on ApiException catch (error) {
      // Already gone is what the user wanted.
      if (error case ApiErrorException(code: ApiErrorCode.notFound)) {
        // Fall through to take it off the list.
      } else {
        return error.message;
      }
    }
    if (ref.mounted) {
      _update(
        (contacts) => [
          for (final each in contacts)
            if (each.id != contact.id) each,
        ],
      );
    }
    return null;
  }

  void _update(
    List<TrustedContact> Function(List<TrustedContact> contacts) change,
  ) {
    if (state.value case final contacts?) state = AsyncData(change(contacts));
  }
}

/// How raising an emergency went.
@immutable
sealed class EmergencyOutcome {
  const EmergencyOutcome();
}

final class EmergencyRaised extends EmergencyOutcome {
  const EmergencyRaised(this.alert);

  final EmergencyAlert alert;
}

/// The alert didn't reach the server, so nobody was told.
final class EmergencyNotSent extends EmergencyOutcome {
  const EmergencyNotSent(this.message);

  final String message;
}

final emergencyAlerterProvider = Provider<EmergencyAlerter>(
  EmergencyAlerter.new,
);

/// Raises an emergency: the user's trusted contacts are emailed, with roughly
/// where the user is when the phone can say.
final class EmergencyAlerter {
  EmergencyAlerter(this._ref);

  /// How long the alert waits for the phone to say where it is. It never waits
  /// longer: the alert matters more than the map.
  static const locationWait = Duration(seconds: 6);

  final Ref _ref;

  Future<EmergencyOutcome> raise({String? note}) async {
    final repository = _ref.read(trustedContactsRepositoryProvider);
    final location = await _roughlyWhere();
    try {
      return EmergencyRaised(
        await repository.raiseEmergency(note: note, location: location),
      );
    } on ApiException catch (error) {
      return EmergencyNotSent(error.message);
    }
  }

  /// Where the phone is, if it may say so without asking now: a permission
  /// dialog is the last thing someone in trouble needs.
  Future<GeoPoint?> _roughlyWhere() async {
    final result = await _ref
        .read(locationServiceProvider)
        .findApproximateLocation(askPermission: false)
        .timeout(locationWait, onTimeout: () => const LocationUnavailable());
    return switch (result) {
      LocationFound(:final point) => point,
      _ => null,
    };
  }
}
