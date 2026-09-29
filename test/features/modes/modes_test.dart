import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/config/server_config.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';
import 'package:kinvo/src/features/modes/domain/mode_choice.dart';
import 'package:kinvo/src/features/modes/domain/mode_filters.dart';
import 'package:kinvo/src/features/modes/domain/user_modes.dart';
import 'package:kinvo/src/features/modes/presentation/screens/modes_screen.dart';
import 'package:kinvo/src/features/more/presentation/screens/settings_screen.dart';
import 'package:kinvo/src/features/verification/presentation/verification_methods_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_kinvo_server.dart';

/// Modes: which are on, the main one, and switching between them from
/// Discover. The chip on Discover opens every mode even with one on, since
/// that's where others are switched on — before, with one mode it did
/// nothing at all.
const _ada = FakePerson(id: 'p1', name: 'Ada');
const _nia = FakePerson(id: 'p2', name: 'Nia');

FakeKinvoServer _server() {
  return FakeKinvoServer()
    ..completeProfile()
    ..isOnboarded = true
    ..decks['dating'] = [_ada]
    ..decks['networking'] = [_nia];
}

Future<AppHarness> _openDiscover(
  WidgetTester tester,
  FakeKinvoServer server,
) async {
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

/// The mode chip at the top of Discover, showing [mode].
Finder _chip(String mode) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Semantics &&
        widget.properties.label == 'Mode: $mode. Change mode',
  );
}

Future<void> _openSwitcher(
  WidgetTester tester,
  AppHarness app,
  String showing,
) async {
  await tester.tap(_chip(showing));
  await app.pumpUntilFound(find.text('Select Mode'));
  // Let the sheet finish sliding up before tapping in it.
  await tester.pump(const Duration(milliseconds: 500));
}

/// [label] on the dialog that's open. The mode switcher can still be sliding
/// away behind it, with its own "Turn on" labels.
Finder _inDialog(String label) {
  return find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text(label),
  );
}

Future<void> _tapInDialog(WidgetTester tester, String label) async {
  await tester.tap(_inDialog(label));
  await tester.pumpAndSettle();
}

/// The switch on [mode]'s row in Your modes.
Finder _switchFor(String mode) {
  return find.descendant(
    of: find.ancestor(of: find.text(mode), matching: find.byType(InkWell)),
    matching: find.byType(Switch),
  );
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

void main() {
  group('the switcher on Discover', () {
    testWidgets('opens every mode even with only one on', (tester) async {
      final server = _server();
      final app = await _openDiscover(tester, server);

      await _openSwitcher(tester, app, 'Dating');

      for (final mode in ['Dating', 'Study Buddy', 'Networking', 'Cuddle']) {
        expect(find.text(mode), findsWidgets, reason: mode);
      }
      expect(find.text('ACTIVE'), findsOneWidget);
      // Two off modes can be switched on; Cuddle needs a verified identity.
      expect(find.text('Turn on'), findsNWidgets(2));
      expect(find.text('Verify'), findsOneWidget);

      Navigator.of(tester.element(find.text('Select Mode'))).pop();
      await app.pumpUntilLoaded();
    });

    testWidgets('asks before switching a mode on, then shows it', (
      tester,
    ) async {
      final server = _server();
      final app = await _openDiscover(tester, server);

      // Not now changes nothing.
      await _openSwitcher(tester, app, 'Dating');
      await tester.tap(find.text('Networking'));
      await app.pumpUntilFound(find.text('Turn on Networking?'));
      await _tapInDialog(tester, 'Not now');
      expect(server.enabledModes, ['dating']);

      await _openSwitcher(tester, app, 'Dating');
      await tester.tap(find.text('Networking'));
      await app.pumpUntilFound(find.text('Turn on Networking?'));
      await tester.tap(_inDialog('Turn on'));

      await app.pumpUntilFound(find.text('Networking is on.'));
      expect(server.enabledModes, ['dating', 'networking']);
      // And Discover shows it at once.
      await app.pumpUntilFound(_chip('Networking'));
      await app.pumpUntilFound(find.text('Nia'));
      await app.pumpUntilLoaded();
    });

    testWidgets('shows a mode that is already on straight away', (
      tester,
    ) async {
      final server = _server()..enabledModes.add('networking');
      final app = await _openDiscover(tester, server);

      await _openSwitcher(tester, app, 'Dating');
      await tester.tap(find.text('Networking'));

      await app.pumpUntilFound(_chip('Networking'));
      await app.pumpUntilFound(find.text('Nia'));
      expect(find.text('Turn on Networking?'), findsNothing);
      await app.pumpUntilLoaded();
    });

    testWidgets("offers the upgrade at the plan's limit", (tester) async {
      final server = _server()..maxModes = 1;
      final app = await _openDiscover(tester, server);

      await _openSwitcher(tester, app, 'Dating');
      await tester.tap(find.text('Networking'));
      await app.pumpUntilFound(find.text('Turn on Networking?'));
      await tester.tap(_inDialog('Turn on'));

      await app.pumpUntilFound(
        find.text('Your plan includes 1 modes at a time. Upgrade for more.'),
      );
      expect(server.enabledModes, ['dating']);
      await app.pumpUntilLoaded();
    });

    testWidgets('points the way to verification for Cuddle', (tester) async {
      final server = _server();
      final app = await _openDiscover(tester, server);

      await _openSwitcher(tester, app, 'Dating');
      await tester.tap(find.text('Cuddle'));
      await app.pumpUntilFound(find.text('Verify to use Cuddle'));
      await tester.tap(_inDialog('Get verified'));

      await app.pumpUntilFound(find.byType(VerificationMethodsScreen));
      expect(server.enabledModes, ['dating']);
      await app.pumpUntilLoaded();
    });
  });

  group('Your modes', () {
    testWidgets('switches modes on and off, and changes the main one', (
      tester,
    ) async {
      final server = _server();
      final app = await _openDiscover(tester, server);
      await _openSwitcher(tester, app, 'Dating');
      await tester.tap(find.text('Manage your modes'));
      await app.pumpUntilFound(find.byType(ModesScreen));
      await app.pumpUntilLoaded();
      expect(find.textContaining('1 of 3 on'), findsOneWidget);

      await _tap(tester, _switchFor('Networking'));
      await app.pumpUntilFound(find.text('Networking is on.'));
      expect(server.enabledModes, ['dating', 'networking']);

      await _tap(tester, find.text('Make Networking my main mode'));
      await app.pumpUntilFound(
        find.text('Networking is your main mode. Kinvo opens in it.'),
      );
      expect(server.primaryMode, 'networking');

      await _tap(tester, _switchFor('Dating'));
      await app.pumpUntilFound(find.text('Dating is off.'));
      expect(server.enabledModes, ['networking']);

      // The last mode stays on, without asking the server.
      final before = app.adapter.requests.length;
      await _tap(tester, _switchFor('Networking'));
      await app.pumpUntilFound(
        find.text(
          'Keep at least one mode on. Discover needs one to show you people.',
        ),
      );
      expect(server.enabledModes, ['networking']);
      expect(app.adapter.requests, hasLength(before));
      await app.pumpUntilLoaded();
    });

    testWidgets('says when the plan is full, and offers the plans', (
      tester,
    ) async {
      final server = _server()
        ..maxModes = 2
        ..enabledModes.add('networking');
      final app = await _openDiscover(tester, server);

      unawaited(app.router.push(AppRoutes.modes));
      await app.pumpUntilFound(find.byType(ModesScreen));
      await app.pumpUntilLoaded();

      expect(find.textContaining('2 of 2 on'), findsOneWidget);
      expect(find.text('See plans'), findsOneWidget);
    });

    testWidgets('opens from Profile and from Settings', (tester) async {
      final server = _server();
      final app = await _openDiscover(tester, server);

      app.router.go(AppRoutes.profile);
      await app.pumpUntilLoaded();
      await _tap(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Modes: 1',
        ),
      );
      await app.pumpUntilFound(find.byType(ModesScreen));
      await app.pumpUntilLoaded();

      app.router.go(AppRoutes.settings);
      await app.pumpUntilFound(find.byType(SettingsScreen));
      await _tap(tester, find.text('Your modes'));
      await app.pumpUntilFound(find.byType(ModesScreen));
      await app.pumpUntilLoaded();
    });
  });

  group('modeChoicesFrom', () {
    ModeOption option(String value, String label) => ModeOption(
      value: value,
      label: label,
      description: '$label, described.',
      likeLabel: 'Like',
      superLikeLabel: 'Super Like',
    );

    UserMode mode(
      String value, {
      bool on = false,
      bool main = false,
      bool canEnable = true,
      bool verify = false,
    }) {
      return UserMode(
        mode: value,
        isEnabled: on,
        isPrimary: main,
        canEnable: canEnable,
        requiresVerification: verify,
        filters: const ModeFilters(
          minAge: 18,
          maxAge: 99,
          radiusMetres: 48280,
          verifiedOnly: false,
        ),
      );
    }

    test(
      "lists every mode in the catalogue's order, as the account has it",
      () {
        final choices = modeChoicesFrom(
          UserModes(
            modes: [
              mode('networking', on: true),
              mode('dating', on: true, main: true),
              mode('cuddle', canEnable: false, verify: true),
              // Enabled, but newer than the catalogue.
              mode('book_club', on: true),
            ],
            maxEnabled: 3,
          ),
          ServerConfig(
            modes: [
              option('dating', 'Dating'),
              option('networking', 'Networking'),
              option('cuddle', 'Cuddle'),
              option('fitness', 'Fitness'),
            ],
            interests: const [],
            limits: const ProfileLimits(
              maxInterests: 10,
              maxPrompts: 3,
              maxPhotos: 6,
              bioMaxLength: 500,
            ),
          ),
        );

        expect(
          [for (final choice in choices) choice.value],
          ['dating', 'networking', 'cuddle', 'fitness', 'book_club'],
        );
        expect(choices[0].isMain, isTrue);
        expect(choices[1].isOn, isTrue);
        expect(choices[2].needsVerification, isTrue);
        // A mode the server didn't list for the account can't be switched on.
        expect(choices[3].canEnable, isFalse);
        expect(choices[3].isUnavailable, isTrue);
        expect(choices[4].label, 'Book club');
      },
    );
  });
}
