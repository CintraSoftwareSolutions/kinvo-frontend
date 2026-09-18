import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/core/widgets/flow_widgets.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_kinvo_server.dart';
import '../../helpers/test_backend.dart';

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

/// Waits for a sheet or dialog to finish opening, then taps [finder] in it.
Future<void> _tapWhenOpen(WidgetTester tester, Finder finder) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(finder);
}

Finder _switch(String title) => find.widgetWithText(SwitchListTile, title);

bool _isOn(WidgetTester tester, String title) {
  return tester.widget<SwitchListTile>(_switch(title)).value;
}

void main() {
  testWidgets('the privacy switches save as they change', (tester) async {
    final server = _server();
    final app = await _open(tester, server, AppRoutes.privacy);
    await app.pumpUntilFound(_switch('Show my distance'));
    expect(_isOn(tester, 'Show my distance'), isTrue);

    await tester.tap(_switch('Show my distance'));
    await app.pumpUntil(
      () => !server.showDistance,
      reason: 'the distance is hidden',
    );
    expect(_isOn(tester, 'Show my distance'), isFalse);

    await tester.tap(_switch("Show when I'm active"));
    await app.pumpUntil(
      () => !server.showLastActive,
      reason: 'the activity is hidden',
    );
  });

  testWidgets('a switch that could not be saved goes back and says why', (
    tester,
  ) async {
    final server = _server();
    server.intercept = (options) async {
      if (options.method == 'PATCH' && options.path.endsWith('/settings')) {
        return jsonResponse(
          503,
          errorEnvelope('SERVICE_UNAVAILABLE', 'Please try again shortly.'),
        );
      }
      return null;
    };
    final app = await _open(tester, server, AppRoutes.privacy);
    await app.pumpUntilFound(_switch("Show when I'm active"));

    await tester.tap(_switch("Show when I'm active"));
    await app.pumpUntilFound(find.text('Please try again shortly.'));

    expect(_isOn(tester, "Show when I'm active"), isTrue);
    expect(server.showLastActive, isTrue);
  });

  testWidgets('takes a break for a week, then comes back', (tester) async {
    final server = _server();
    final app = await _open(tester, server, AppRoutes.privacy);
    final takeBreak = find.widgetWithText(OutlineActionButton, 'Take a break');
    await app.pumpUntilFound(takeBreak);

    await tester.tap(takeBreak);
    await app.pumpUntilFound(find.text('For a week'));
    await _tapWhenOpen(tester, find.text('For a week'));
    await app.pumpUntilFound(find.text("You're taking a break"));

    expect(server.isSnoozed, isTrue);
    expect(server.snoozeEndsAt, server.now().add(const Duration(days: 7)));
    expect(
      find.textContaining('Nobody new sees you in Discover until'),
      findsOneWidget,
    );

    await tester.tap(find.text('Come back now'));
    await app.pumpUntilFound(takeBreak);
    expect(server.isSnoozed, isFalse);
  });

  testWidgets('the Profile tab says when the user is on a break', (
    tester,
  ) async {
    final server = _server()..isSnoozed = true;
    final app = await _open(tester, server, AppRoutes.profile);

    await app.pumpUntilFound(find.text("You're taking a break"));
    await tester.tap(find.text("You're taking a break"));
    await app.pumpUntilFound(find.text('Come back now'));
  });

  group('devices', () {
    FakeKinvoServer withDevices() {
      final server = _server();
      return server
        ..devices.addAll([
          FakeDevice(
            id: 'row-this',
            deviceId: testDeviceId,
            model: 'Google Pixel 8',
            osVersion: 'Android 15',
            lastSeenAt: server.now(),
          ),
          FakeDevice(
            id: 'row-tablet',
            deviceId: 'tablet',
            platform: 'ios',
            model: 'iPad Air',
            osVersion: 'iPadOS 18.1',
            lastSeenAt: server.now().subtract(const Duration(days: 2)),
          ),
          FakeDevice(
            id: 'row-old',
            deviceId: 'old-phone',
            model: 'Google Pixel 6',
            lastSeenAt: server.now().subtract(const Duration(days: 1)),
          ),
        ]);
    }

    Finder dialogButton(String label) {
      return find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(label),
      );
    }

    testWidgets('signs a lost phone out', (tester) async {
      final server = withDevices();
      final app = await _open(tester, server, AppRoutes.devices);
      await app.pumpUntilFound(find.text('Google Pixel 6'));
      expect(find.text('Google Pixel 8'), findsOneWidget);
      expect(find.textContaining('Using now'), findsOneWidget);
      expect(find.textContaining('Active yesterday'), findsOneWidget);

      final row = find.widgetWithText(ListTile, 'Google Pixel 6');
      await tester.tap(
        find.descendant(of: row, matching: find.text('Sign out')),
      );
      await app.pumpUntilFound(find.text('Sign out Google Pixel 6?'));
      await _tapWhenOpen(tester, dialogButton('Sign out'));

      await app.pumpUntilFound(find.text('Signed out Google Pixel 6.'));
      expect(server.devicesSignedOut, ['old-phone']);
      expect(find.text('Google Pixel 6'), findsNothing);
    });

    testWidgets('signs out every other device', (tester) async {
      final server = withDevices();
      final app = await _open(tester, server, AppRoutes.devices);
      await app.pumpUntilFound(find.text('Sign out all 2 other devices'));

      await tester.tap(find.text('Sign out all 2 other devices'));
      await app.pumpUntilFound(find.text('Sign out 2 other devices?'));
      await _tapWhenOpen(tester, dialogButton('Sign out'));

      await app.pumpUntilFound(find.text('Signed out 2 devices.'));
      expect(server.devicesSignedOut, ['tablet', 'old-phone']);
      expect(find.text("You're not signed in anywhere else."), findsOneWidget);
    });
  });

  testWidgets('shows distances in kilometres once chosen', (tester) async {
    final server = _server()
      ..decks['dating'] = [
        const FakePerson(id: 'p1', name: 'Priya', distanceMetres: 6437),
      ];
    final app = await _open(tester, server, AppRoutes.discover);
    await app.pumpUntilFound(find.text('4 miles away'));

    app.router.go(AppRoutes.settings);
    await app.pumpUntilFound(find.text('Distance units'));
    await tester.tap(find.text('Distance units'));
    await app.pumpUntilFound(find.text('Kilometres'));
    await _tapWhenOpen(tester, find.text('Kilometres'));
    await app.pumpUntil(
      () => server.distanceUnit == 'kilometres',
      reason: 'the unit is saved',
    );

    app.router.go(AppRoutes.discover);
    await app.pumpUntilFound(find.text('6 km away'));
    await app.pumpUntilLoaded();
  });

  testWidgets("opens a mode's filters from Settings", (tester) async {
    final server = _server();
    final app = await _open(tester, server, AppRoutes.settings);
    await app.pumpUntilFound(find.text('Distance and age range'));

    await tester.tap(find.text('Distance and age range'));
    await app.pumpUntilFound(find.text('Dating filters'));
    expect(find.text('Within 30 miles'), findsOneWidget);
  });

  testWidgets('the demo settings change without an account', (tester) async {
    final app = await pumpKinvoApp(tester);
    await app.pumpUntilFound(find.text('Explore Demo'));
    await tester.tap(find.text('Explore Demo'));
    await app.pumpUntilFound(find.byType(DiscoverScreen));
    await app.pumpUntilLoaded();

    app.router.go(AppRoutes.privacy);
    await app.pumpUntilFound(_switch('Show my distance'));
    await tester.tap(_switch('Show my distance'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_isOn(tester, 'Show my distance'), isFalse);

    app.router.go(AppRoutes.devices);
    await app.pumpUntilFound(find.text('iPad Air'));
    expect(app.adapter.requests, isEmpty);
  });
}
