import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';
import 'package:kinvo/src/features/profile/presentation/screens/profile_edit_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_kinvo_server.dart';

FakeKinvoServer _server() {
  return FakeKinvoServer()
    ..completeProfile()
    ..isOnboarded = true
    ..jobTitle = 'Designer'
    ..organisation = 'Foundry';
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

/// Scrolls the screen until [finder] shows, then taps it.
Future<void> _scrollToAndTap(WidgetTester tester, Finder finder) async {
  final page = find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  );
  await tester.scrollUntilVisible(finder, 150, scrollable: page.first);
  await tester.pump();
  await tester.tap(finder);
}

/// The row for [label] on the edit screen.
Finder _row(String label) {
  return find.descendant(
    of: find.byType(ProfileEditScreen),
    matching: find.widgetWithText(ListTile, label),
  );
}

void main() {
  testWidgets('the Profile tab shows the profile and what would complete it', (
    tester,
  ) async {
    final app = await _open(tester, _server(), AppRoutes.profile);

    await app.pumpUntilFound(find.text('Sam Taylor, 31'));
    expect(find.text('Designer at Foundry'), findsOneWidget);
    expect(find.text('Leeds, GB'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('Finish your profile'), findsOneWidget);
    expect(find.text('Write a bio of at least 20 characters'), findsOneWidget);
    // The photos, modes and settings are still on their way.
    await app.pumpUntilLoaded();
  });

  testWidgets('changes a detail from its editor', (tester) async {
    final server = _server();
    final app = await _open(tester, server, AppRoutes.profileEdit);
    await app.pumpUntilFound(_row('Job title'));

    await tester.tap(_row('Job title'));
    await app.pumpUntilFound(
      find.text('Leave it empty to take it off your profile.'),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(
      find.widgetWithText(TextField, 'Job title'),
      '  Product designer ',
    );
    await tester.tap(find.text('Save'));
    await app.pumpUntilGone(
      find.text('Leave it empty to take it off your profile.'),
    );

    expect(server.jobTitle, 'Product designer');
    expect(find.text('Product designer'), findsOneWidget);
  });

  testWidgets('says why a detail was refused, and keeps the editor open', (
    tester,
  ) async {
    final server = _server();
    server.intercept = (options) async {
      if (options.method == 'PATCH' && options.path.endsWith('/users/me')) {
        return jsonResponse(
          400,
          errorEnvelope(
            'VALIDATION_FAILED',
            'Some fields need attention.',
            details: {
              'display_name': ['That name is not allowed.'],
            },
          ),
        );
      }
      return null;
    };
    final app = await _open(tester, server, AppRoutes.profileEdit);
    await app.pumpUntilFound(_row('Name'));

    await tester.tap(_row('Name'));
    await app.pumpUntilFound(find.text('Your name'));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.widgetWithText(TextField, 'Name'), '   ');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter your name.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Admin');
    await tester.tap(find.text('Save'));
    await app.pumpUntilFound(find.text('That name is not allowed.'));
    expect(server.displayName, 'Sam Taylor');
    expect(find.text('Your name'), findsOneWidget);
  });

  testWidgets('answers a lifestyle question, then takes it off', (
    tester,
  ) async {
    final server = _server();
    final app = await _open(tester, server, AppRoutes.profileEdit);
    await app.pumpUntilFound(_row('Name'));

    await _scrollToAndTap(tester, _row('Drinking'));
    await app.pumpUntilFound(find.text('Socially'));
    await _tapWhenOpen(tester, find.text('Socially'));
    await app.pumpUntil(
      () => server.lifestyle['drinking'] == 'socially',
      reason: 'the answer is saved',
    );
    await app.pumpUntilGone(find.text('Regularly'));
    expect(find.text('Socially'), findsOneWidget);

    await tester.tap(_row('Drinking'));
    await app.pumpUntilFound(find.text('Take it off my profile'));
    await _tapWhenOpen(tester, find.text('Take it off my profile'));
    await app.pumpUntil(
      () => !server.lifestyle.containsKey('drinking'),
      reason: 'the answer is cleared',
    );
    await app.pumpUntilGone(find.text('Take it off my profile'));
  });

  testWidgets('adds a photo, makes it the main one, and deletes the old one', (
    tester,
  ) async {
    // The photo tiles are found by what a screen reader hears.
    final semantics = tester.ensureSemantics();
    final server = _server();
    final app = await _open(tester, server, AppRoutes.profileEdit);
    await app.pumpUntilFound(find.bySemanticsLabel('Main photo, 1 of 1'));

    await tester.tap(find.bySemanticsLabel('Add a photo').first);
    await app.pumpUntilFound(find.text('Choose from your photos'));
    await _tapWhenOpen(tester, find.text('Choose from your photos'));
    await app.pumpUntilFound(find.bySemanticsLabel('Photo 2 of 2'));
    final added = server.photos.last.id;
    expect(server.photos, hasLength(2));

    await tester.tap(find.bySemanticsLabel('Photo 2 of 2'));
    await app.pumpUntilFound(find.text('Make it my main photo'));
    await _tapWhenOpen(tester, find.text('Make it my main photo'));
    await app.pumpUntil(
      () => server.photos.first.id == added,
      reason: 'the new photo is the main one',
    );

    await app.pumpUntilGone(find.text('Make it my main photo'));
    await tester.tap(find.bySemanticsLabel('Photo 2 of 2'));
    await app.pumpUntilFound(find.text('Delete photo'));
    await _tapWhenOpen(tester, find.text('Delete photo'));
    await app.pumpUntilFound(find.text('Delete this photo?'));
    await _tapWhenOpen(tester, find.text('Delete'));
    await app.pumpUntil(
      () => server.photos.length == 1,
      reason: 'the old photo is deleted',
    );
    expect(server.photos.single.id, added);
    await app.pumpUntilFound(find.bySemanticsLabel('Main photo, 1 of 1'));
    semantics.dispose();
  });

  testWidgets('keeps the only photo and says why', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await _open(tester, _server(), AppRoutes.profileEdit);
    await app.pumpUntilFound(find.bySemanticsLabel('Main photo, 1 of 1'));

    await tester.tap(find.bySemanticsLabel('Main photo, 1 of 1'));
    await app.pumpUntilFound(find.text('Your main photo'));

    expect(
      find.text('Your profile needs at least one photo. Add another first.'),
      findsOneWidget,
    );
    expect(find.text('Make it my main photo'), findsNothing);
    semantics.dispose();
  });

  testWidgets('chooses interests', (tester) async {
    final server = _server();
    final app = await _open(tester, server, AppRoutes.profileEdit);
    await app.pumpUntilFound(_row('Name'));

    await _scrollToAndTap(tester, find.text('Change'));
    await app.pumpUntilFound(find.text('Save interests'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('1 of 10 chosen'), findsOneWidget);
    await tester.tap(find.text('Travel'));
    await tester.tap(find.text('Running'));
    await tester.pump();
    expect(find.text('3 of 10 chosen'), findsOneWidget);

    await tester.tap(find.text('Save interests'));
    await app.pumpUntilFound(find.byType(ProfileEditScreen));
    await app.pumpUntil(
      () => server.interests.length == 3,
      reason: 'the interests are saved',
    );
    expect(server.interests, ['music', 'travel', 'running']);
  });

  testWidgets('answers a prompt, then changes the answer', (tester) async {
    final server = _server();
    final app = await _open(tester, server, AppRoutes.profileEdit);
    await app.pumpUntilFound(_row('Name'));

    await _scrollToAndTap(tester, find.text('Answer a prompt'));
    await app.pumpUntilFound(find.text('Choose a prompt'));
    await _tapWhenOpen(tester, find.text('My go-to order is…'));
    await app.pumpUntilFound(find.widgetWithText(TextField, 'Your answer'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(
      find.widgetWithText(TextField, 'Your answer'),
      'A flat white.',
    );
    await tester.tap(find.text('Save'));
    await app.pumpUntil(
      () => server.prompts.isNotEmpty,
      reason: 'the prompt is saved',
    );
    expect(server.prompts.single, (
      slug: 'go_to_order',
      answer: 'A flat white.',
    ));
    await app.pumpUntilGone(find.widgetWithText(TextField, 'Your answer'));

    await tester.tap(find.text('A flat white.'));
    await app.pumpUntilFound(find.text('Remove this prompt'));
    await _tapWhenOpen(tester, find.text('Remove this prompt'));
    await app.pumpUntil(
      () => server.prompts.isEmpty,
      reason: 'the prompt is removed',
    );
    await app.pumpUntilGone(find.text('Remove this prompt'));
  });

  testWidgets('shows the profile as other people see it', (tester) async {
    final server = _server()
      ..bio = 'Weekend hiker and coffee snob.'
      ..showDistance = false;
    final app = await _open(tester, server, AppRoutes.profile);
    await app.pumpUntilFound(find.text('Sam Taylor, 31'));

    await _scrollToAndTap(tester, find.text('How others see me'));
    await app.pumpUntilFound(find.text('How others see you'));
    await app.pumpUntilFound(find.text('Weekend hiker and coffee snob.'));

    expect(find.text('Sam Taylor, 31'), findsOneWidget);
    expect(find.text('Designer at Foundry'), findsOneWidget);
    expect(find.textContaining('Your distance is hidden.'), findsOneWidget);
  });
}
