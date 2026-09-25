import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';
import 'package:kinvo/src/features/more/presentation/screens/safety_center_screen.dart';
import 'package:kinvo/src/features/more/presentation/screens/trusted_contacts_screen.dart';
import 'package:kinvo/src/features/plans/presentation/screens/plan_detail_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_kinvo_server.dart';

FakeKinvoServer _server() {
  return FakeKinvoServer()
    ..completeProfile()
    ..isOnboarded = true;
}

/// A signed-in, onboarded account, on [location].
Future<AppHarness> _open(
  WidgetTester tester,
  FakeKinvoServer server,
  String location,
) async {
  final app = await pumpKinvoApp(
    tester,
    savedSession: liveSession(),
    respond: server.respond,
    realtime: server.realtime,
    clock: server.now,
  );
  await app.pumpUntilFound(find.byType(DiscoverScreen));
  await app.pumpUntilLoaded();
  app.router.go(location);
  await app.pumpUntilLoaded();
  return app;
}

Finder _field(String label) => find.widgetWithText(TextField, label);

/// Waits for a sheet or dialog to finish opening, then taps [finder] in it.
Future<void> _tapWhenOpen(WidgetTester tester, Finder finder) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(finder);
}

void main() {
  testWidgets('alerts trusted contacts, and says exactly who was reached', (
    tester,
  ) async {
    final server = _server()
      ..contacts.addAll([
        FakeContact(id: 'c1', name: 'Sister', email: 'sister@example.com'),
        FakeContact(id: 'c2', name: 'Brother', phone: '+447700900123'),
      ]);
    final app = await _open(tester, server, AppRoutes.safetyCenter);
    await app.pumpUntilFound(find.byType(SafetyCenterScreen));
    await app.pumpUntilFound(find.text('2 of 5 added.'));

    await tester.tap(find.text('Alert my trusted contacts'));
    await app.pumpUntilFound(find.text('Alert your trusted contacts?'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(
      _field('Add a message (optional)'),
      'Leaving the bar now',
    );
    await tester.tap(find.text('Send alert'));

    await app.pumpUntilFound(
      find.text(
        'We emailed 1 of your 2 trusted contacts. Call the others yourself.',
      ),
    );
    expect(find.text('Emailed'), findsOneWidget);
    expect(find.text('No email address'), findsOneWidget);
    expect(server.emergencies.single['note'], 'Leaving the bar now');
    expect(server.emergencies.single['latitude'], isNotNull);

    await tester.tap(find.text('Done'));
    await app.pumpUntilGone(find.text('Done'));
  });

  testWidgets("an alert that couldn't be sent says so, and can be tried "
      'again', (tester) async {
    var offline = true;
    final server = _server()
      ..contacts.add(
        FakeContact(id: 'c1', name: 'Sister', email: 'sister@example.com'),
      );
    server.intercept = (options) async {
      if (offline && options.path.endsWith('/safety/emergency')) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const SocketException('Network is unreachable'),
        );
      }
      return null;
    };
    final app = await _open(tester, server, AppRoutes.safetyCenter);
    await app.pumpUntilFound(find.byType(SafetyCenterScreen));

    await tester.tap(find.text('Alert my trusted contacts'));
    await app.pumpUntilFound(find.text('Alert your trusted contacts?'));
    await _tapWhenOpen(tester, find.text('Send alert'));
    await app.pumpUntilFound(find.text("Your alert wasn't sent"));

    offline = false;
    await tester.tap(find.text('Try again'));
    await app.pumpUntilFound(find.text('We emailed your trusted contact.'));
    expect(server.emergencies, hasLength(1));
  });

  testWidgets('adds, changes and removes trusted contacts', (tester) async {
    final server = _server();
    final app = await _open(tester, server, AppRoutes.trustedContacts);
    await app.pumpUntilFound(find.byType(TrustedContactsScreen));
    await app.pumpUntilFound(find.text('No trusted contacts yet'));

    await tester.tap(find.text('Add a contact'));
    await app.pumpUntilFound(find.text('Add a trusted contact'));
    await _tapWhenOpen(tester, find.text('Save'));
    await tester.pump();
    expect(find.text('Add their name.'), findsOneWidget);
    expect(
      find.text('Add an email address, so Kinvo can alert them.'),
      findsOneWidget,
    );

    await tester.enterText(_field('Name'), 'Sister');
    await tester.enterText(_field('Email'), 'not an address');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text("That email address doesn't look right."), findsOneWidget);

    await tester.enterText(_field('Email'), 'sister@example.com');
    await tester.tap(find.text('Save'));
    await app.pumpUntilFound(find.text('Sister is a trusted contact.'));
    await app.pumpUntilGone(find.text('Add a trusted contact'));
    expect(server.contacts.single.email, 'sister@example.com');

    // Change how they're known.
    await tester.tap(find.text('Sister'));
    await app.pumpUntilFound(find.text('Edit contact'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(_field('How you know them (optional)'), 'Big sis');
    await tester.tap(find.text('Save'));
    await app.pumpUntilGone(find.text('Edit contact'));
    expect(server.contacts.single.relationship, 'Big sis');

    // And take them off.
    await tester.tap(find.text('Sister'));
    await app.pumpUntilFound(find.text('Remove contact'));
    await _tapWhenOpen(tester, find.text('Remove contact'));
    await app.pumpUntilFound(find.text('Remove Sister?'));
    await _tapWhenOpen(tester, find.text('Remove'));
    await app.pumpUntilFound(find.text('No trusted contacts yet'));
    expect(server.contacts, isEmpty);
  });

  testWidgets('tells a trusted contact about a confirmed plan', (tester) async {
    final server = _server()
      ..contacts.add(
        FakeContact(id: 'c1', name: 'Sister', email: 'sister@example.com'),
      );
    final match = FakeMatch(
      id: 'match-p1',
      mode: 'dating',
      person: const FakePerson(id: 'p1', name: 'Sam'),
      isSuperLike: false,
      matchedAt: server.now(),
      expiresAt: server.now().add(const Duration(days: 10)),
    );
    server.matches.add(match);
    final plan = server.planFromPerson(
      match,
      place: 'Cinema',
      at: server.now().add(const Duration(days: 1)),
      status: 'confirmed',
      announce: false,
    );
    final app = await _open(tester, server, AppRoutes.plan(plan.id));
    await app.pumpUntilFound(find.byType(PlanDetailScreen));

    await tester.ensureVisible(find.text('Tell a trusted contact'));
    await tester.pump();
    await tester.tap(find.text('Tell a trusted contact'));
    await app.pumpUntilFound(find.byType(CheckboxListTile));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Sister'));
    await tester.pump();
    await tester.tap(find.text('Send'));

    await app.pumpUntilFound(find.text('Emailed'));
    expect(plan.sharedWith, {'c1'});
    await tester.tap(find.text('Done'));
    await app.pumpUntilFound(find.text('One of your trusted contacts knows'));
  });
}
