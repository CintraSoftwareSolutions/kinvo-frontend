import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/auth/auth_providers.dart';
import 'package:kinvo/src/core/location/location_service.dart';
import 'package:kinvo/src/features/safety/domain/trusted_contact.dart';
import 'package:kinvo/src/features/safety/presentation/controllers/trusted_contacts_controllers.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_kinvo_server.dart';
import '../../helpers/test_backend.dart';

void main() {
  group('reading from the API', () {
    test('a trusted contact', () {
      final contact = TrustedContact.fromJson(const {
        'id': 'c1',
        'name': 'Sister',
        'phone': null,
        'email': 'sister@example.com',
        'relationship': 'Sister',
        'created_at': '2026-09-18T09:00:00.000Z',
      });

      expect(contact.name, 'Sister');
      expect(contact.canBeAlerted, isTrue);
    });

    test('what happened to each contact', () {
      final alert = EmergencyAlert.fromJson(const {
        'summary': 'We emailed 1 of your 2 trusted contacts.',
        'contacts': [
          {'id': 'c1', 'name': 'Sister', 'delivery': 'emailed'},
          {'id': 'c2', 'name': 'Brother', 'delivery': 'no_email'},
          {'id': 'c3', 'name': 'Friend', 'delivery': 'carrier_pigeon'},
        ],
      });

      expect(
        [for (final contact in alert.contacts) contact.delivery],
        [
          ContactDelivery.emailed,
          ContactDelivery.noEmail,
          ContactDelivery.unknown,
        ],
      );
      expect(ContactDelivery.alreadyTold.reached, isTrue);
      expect(ContactDelivery.failed.reached, isFalse);
    });

    test('a shared plan', () {
      final shared = PlanShare.fromJson(const {
        'shared': 1,
        'contacts': [
          {'id': 'c1', 'name': 'Sister', 'delivery': 'already_told'},
        ],
      });

      expect(shared.shared, 1);
      expect(shared.contacts.single.delivery, ContactDelivery.alreadyTold);
    });
  });

  group('with an account', () {
    late FakeKinvoServer server;
    late TestBackend backend;
    late ProviderContainer container;

    setUp(() async {
      server = FakeKinvoServer()
        ..completeProfile()
        ..isOnboarded = true;
      backend = TestBackend(respond: server.respond);
      await backend.tokenStore.write(liveSession());
      container = backend.createContainer(clock: server.now);
      await container.read(sessionManagerProvider).ready;
    });

    Future<TrustedContactsController> openContacts() async {
      container.listen(trustedContactsProvider, (_, _) {});
      await container.read(trustedContactsProvider.future);
      return container.read(trustedContactsProvider.notifier);
    }

    List<String> names() {
      return [
        for (final contact
            in container.read(trustedContactsProvider).requireValue)
          contact.name,
      ];
    }

    test('adds, changes and removes contacts', () async {
      final contacts = await openContacts();

      final added = await contacts.save(
        const ContactDetails(
          name: 'Sister',
          email: 'sister@example.com',
          phone: '+447700900123',
        ),
      );
      final contact = (added as ContactSaved).contact;
      expect(names(), ['Sister']);

      // Emptying the phone takes it away.
      await contacts.save(
        const ContactDetails(
          name: 'Sister',
          email: 'sister@example.com',
          phone: '',
        ),
        contactId: contact.id,
      );
      expect(server.contacts.single.phone, isNull);

      expect(await contacts.delete(contact), isNull);
      expect(names(), isEmpty);
      expect(server.contacts, isEmpty);
    });

    test("keeps the server's reasons for each field", () async {
      final contacts = await openContacts();

      final outcome = await contacts.save(const ContactDetails(name: 'Nobody'));

      expect((outcome as ContactRefused).fieldErrors['phone'], isNotEmpty);
    });

    test('an emergency carries roughly where the phone is, and says who was '
        'reached', () async {
      server.contacts.add(
        FakeContact(id: 'c1', name: 'Sister', email: 'sister@example.com'),
      );

      final outcome = await container
          .read(emergencyAlerterProvider)
          .raise(note: 'Feeling unsafe');

      final alert = (outcome as EmergencyRaised).alert;
      expect(alert.summary, 'We emailed your trusted contact.');
      final sent = server.emergencies.single;
      expect(sent['note'], 'Feeling unsafe');
      expect(sent['latitude'], 53.8);
      expect(sent['utc_offset_minutes'], isA<int>());
    });

    test("an emergency doesn't stop to ask for location", () async {
      backend.locationService.result = const LocationPermissionDenied(
        canAskAgain: true,
      );

      await container.read(emergencyAlerterProvider).raise();

      expect(server.emergencies.single.containsKey('latitude'), isFalse);
    });

    test("says when the alert couldn't be sent", () async {
      server.intercept = (options) async {
        if (options.path.endsWith('/safety/emergency')) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: const SocketException('Network is unreachable'),
          );
        }
        return null;
      };

      final outcome = await container.read(emergencyAlerterProvider).raise();

      expect(outcome, isA<EmergencyNotSent>());
    });
  });
}
