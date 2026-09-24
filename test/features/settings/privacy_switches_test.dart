import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/core/units/distance.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';
import 'package:kinvo/src/features/settings/domain/user_settings.dart';
import 'package:kinvo/src/features/settings/presentation/screens/privacy_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_kinvo_server.dart';

/// Who you meet: incognito, verified people only in every mode, and new
/// matches paused. The server applies all three; the app offers them, says
/// what they do, and — for a paused account — never leaves a like that can't
/// work looking like a broken button.
const _unverified = FakePerson(id: 'p1', name: 'Bea');
const _verified = FakePerson(id: 'p2', name: 'Ada', isVerified: true);

FakeKinvoServer _server() {
  return FakeKinvoServer()
    ..completeProfile()
    ..isOnboarded = true
    ..decks['dating'] = [_unverified, _verified];
}

Future<AppHarness> _open(WidgetTester tester, FakeKinvoServer server) async {
  final app = await pumpKinvoApp(
    tester,
    savedSession: liveSession(),
    respond: server.respond,
    clock: server.now,
  );
  await app.pumpUntilFound(find.byType(DiscoverScreen));
  await app.pumpUntilLoaded();
  return app;
}

Future<void> _openPrivacy(AppHarness app) async {
  app.router.go(AppRoutes.privacy);
  await app.pumpUntilFound(find.byType(PrivacyScreen));
  await app.pumpUntilLoaded();
}

/// The switch titled [title].
Finder _switch(String title) => find.widgetWithText(SwitchListTile, title);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

Finder _like() {
  return find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == 'Like',
  );
}

void main() {
  testWidgets('each switch says what it does, and saves', (tester) async {
    final server = _server();
    final app = await _open(tester, server);
    await _openPrivacy(app);

    expect(
      find.text(
        'Only people you like can see you in Discover. Your matches still '
        'can.',
      ),
      findsOneWidget,
    );

    for (final title in [
      'Incognito',
      'Pause new matches',
      'Verified people only',
    ]) {
      await _tap(tester, _switch(title));
      await app.pumpUntilLoaded();
    }

    expect(server.incognito, isTrue);
    expect(server.pauseNewMatches, isTrue);
    expect(server.verifiedOnlyEverywhere, isTrue);

    final saved = app.backend
        .requestsTo('/settings')
        .where((request) => request.method == 'PATCH');
    expect(
      [for (final request in saved) (request.data! as Map).keys.single],
      ['incognito', 'pause_new_matches', 'global_verified_only'],
    );
  });

  testWidgets('verified people only clears Discover of anyone unverified', (
    tester,
  ) async {
    final server = _server();
    final app = await _open(tester, server);
    expect(find.text('Bea'), findsOneWidget);

    await _openPrivacy(app);
    await _tap(tester, _switch('Verified people only'));
    await app.pumpUntilLoaded();

    app.router.go(AppRoutes.discover);
    // Today's cards are fetched again, as the server rebuilt them — once
    // Discover is back on screen, since a hidden deck doesn't reload — and
    // the old ones stay on show until the new ones arrive.
    await app.pumpUntil(
      () => app.backend.requestsTo('/discovery/dating/deck').length >= 2,
      reason: 'the deck is fetched again',
    );
    await app.pumpUntilGone(find.text('Bea'));
    await app.pumpUntilLoaded();
    expect(find.text('Ada'), findsOneWidget);
  });

  testWidgets('a like while paused explains itself and offers to resume', (
    tester,
  ) async {
    final server = _server()..pauseNewMatches = true;
    final app = await _open(tester, server);

    // Said before a like is refused, not only after.
    expect(find.text('New matches are paused'), findsOneWidget);

    await _tap(tester, _like());
    await app.pumpUntilFound(find.text('Resume matching'));

    // Keeping it paused keeps it paused, and the card stays.
    await tester.tap(find.text('Keep paused'));
    await tester.pumpAndSettle();
    expect(server.pauseNewMatches, isTrue);
    expect(find.text('Bea'), findsOneWidget);

    await _tap(tester, _like());
    await app.pumpUntilFound(find.text('Resume matching'));
    await tester.tap(find.text('Resume matching'));
    await app.pumpUntilFound(find.text('Matching is back on.'));

    expect(server.pauseNewMatches, isFalse);
    await app.pumpUntilGone(find.text('New matches are paused'));

    // And the like that was refused now goes through.
    await _tap(tester, _like());
    await app.pumpUntilFound(find.text('Ada'));
    await app.pumpUntilLoaded();
    expect(server.swipes['dating']!.single.userId, 'p1');
  });

  testWidgets('the banner resumes matching on its own', (tester) async {
    final server = _server()..pauseNewMatches = true;
    final app = await _open(tester, server);

    await _tap(tester, find.text('Resume'));
    await app.pumpUntilGone(find.text('New matches are paused'));

    expect(server.pauseNewMatches, isFalse);
    await app.pumpUntilLoaded();
  });

  group('UserSettings', () {
    Map<String, Object?> json(Map<String, Object?> extra) => {
      'distance_unit': 'miles',
      'show_distance': true,
      'show_last_active': true,
      'snooze': {'is_snoozed': false, 'ends_at': null},
      ...extra,
    };

    test('reads the three switches, on only when the server says so', () {
      final on = UserSettings.fromJson(
        json({
          'incognito': true,
          'global_verified_only': true,
          'pause_new_matches': true,
        }),
      );
      expect(on.incognito, isTrue);
      expect(on.verifiedOnlyEverywhere, isTrue);
      expect(on.pauseNewMatches, isTrue);

      // An older server that sends none of them switches nothing on.
      final absent = UserSettings.fromJson(json({}));
      expect(absent.incognito, isFalse);
      expect(absent.verifiedOnlyEverywhere, isFalse);
      expect(absent.pauseNewMatches, isFalse);
    });

    test('keeps every other setting when a break starts or ends', () {
      const settings = UserSettings(
        distanceUnit: DistanceUnit.kilometres,
        showDistance: false,
        showLastActive: true,
        textScale: 1.4,
        incognito: true,
      );

      final onBreak = settings.copyWith(snooze: () => const Snooze());
      final back = onBreak.copyWith(snooze: () => null);

      expect(onBreak.isOnBreak, isTrue);
      expect(back.isOnBreak, isFalse);
      expect(back.textScale, 1.4);
      expect(back.incognito, isTrue);
      expect(back.distanceUnit, DistanceUnit.kilometres);
    });
  });
}
