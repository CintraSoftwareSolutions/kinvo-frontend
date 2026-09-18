import 'package:flutter/foundation.dart';

import '../../../core/network/api_envelope.dart';

/// Someone the user trusts to be told when they need help, or where they're
/// meeting someone.
@immutable
final class TrustedContact {
  const TrustedContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.relationship,
  });

  factory TrustedContact.fromJson(JsonMap json) {
    if (json case {
      'id': final String id,
      'name': final String name,
      'phone': final String? phone,
      'email': final String? email,
      'relationship': final String? relationship,
    } when id.isNotEmpty) {
      return TrustedContact(
        id: id,
        name: name,
        phone: phone,
        email: email,
        relationship: relationship,
      );
    }
    throw const FormatException(
      'Expected a trusted contact with id, name, phone, email and '
      'relationship.',
    );
  }

  final String id;
  final String name;
  final String? phone;
  final String? email;

  /// How the user knows them, such as "Sister".
  final String? relationship;

  /// Whether Kinvo can alert them. Alerts go by email.
  bool get canBeAlerted => email?.isNotEmpty ?? false;
}

/// What the user says about a trusted contact: everything but its id.
@immutable
final class ContactDetails {
  const ContactDetails({
    required this.name,
    this.phone,
    this.email,
    this.relationship,
  });

  final String name;
  final String? phone;
  final String? email;
  final String? relationship;
}

/// What happened when Kinvo tried to tell a trusted contact something.
enum ContactDelivery {
  emailed('emailed'),

  /// They have no email address, so they couldn't be told.
  noEmail('no_email'),

  /// The email didn't send.
  failed('failed'),

  /// Told about the same plan before, so not emailed again.
  alreadyTold('already_told'),

  /// An outcome added to the server after this version of the app.
  unknown('');

  const ContactDelivery(this.wireValue);

  final String wireValue;

  /// Whether they know.
  bool get reached => this == emailed || this == alreadyTold;

  static ContactDelivery fromWireValue(String value) {
    for (final delivery in values) {
      if (delivery != unknown && delivery.wireValue == value) return delivery;
    }
    return unknown;
  }
}

/// What happened for one trusted contact.
@immutable
final class ContactAlert {
  const ContactAlert({
    required this.contactId,
    required this.name,
    required this.delivery,
  });

  factory ContactAlert.fromJson(JsonMap json) {
    if (json case {
      'id': final String id,
      'name': final String name,
      'delivery': final String delivery,
    }) {
      return ContactAlert(
        contactId: id,
        name: name,
        delivery: ContactDelivery.fromWireValue(delivery),
      );
    }
    throw const FormatException('Expected a contact with id, name, delivery.');
  }

  final String contactId;
  final String name;
  final ContactDelivery delivery;

  static List<ContactAlert> listFrom(Object? json) {
    if (json is! List<Object?>) {
      throw const FormatException('Expected a list of contacts.');
    }
    return [
      for (final item in json)
        if (item is JsonMap) ContactAlert.fromJson(item),
    ];
  }
}

/// How raising an emergency went.
@immutable
final class EmergencyAlert {
  const EmergencyAlert({required this.summary, required this.contacts});

  factory EmergencyAlert.fromJson(JsonMap json) {
    if (json case {'summary': final String summary, 'contacts': final list}) {
      return EmergencyAlert(
        summary: summary,
        contacts: ContactAlert.listFrom(list),
      );
    }
    throw const FormatException('Expected an emergency summary and contacts.');
  }

  /// What happened, in a sentence, as the server says it.
  final String summary;

  /// What happened for each trusted contact.
  final List<ContactAlert> contacts;
}

/// How telling trusted contacts about a plan went.
@immutable
final class PlanShare {
  const PlanShare({required this.shared, required this.contacts});

  factory PlanShare.fromJson(JsonMap json) {
    if (json case {'shared': final int shared, 'contacts': final list}) {
      return PlanShare(shared: shared, contacts: ContactAlert.listFrom(list));
    }
    throw const FormatException('Expected a shared count and contacts.');
  }

  /// How many of the user's contacts now know about the plan.
  final int shared;

  /// What happened for each contact asked for.
  final List<ContactAlert> contacts;
}
