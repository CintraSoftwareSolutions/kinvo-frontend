import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';
import 'package:kinvo/src/features/discovery/presentation/widgets/profile_sheet.dart';
import 'package:kinvo/src/features/profile/presentation/widgets/photo_gallery.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_kinvo_server.dart';

const _ada = FakePerson(id: 'p1', name: 'Ada', photoCount: 3);
const _bea = FakePerson(id: 'p2', name: 'Bea', photoCount: 1);

FakeKinvoServer _server({List<FakePerson> deck = const [_ada, _bea]}) {
  return FakeKinvoServer()
    ..completeProfile()
    ..isOnboarded = true
    ..decks['dating'] = [...deck];
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

/// The widget carrying the accessibility label [label].
Finder _labelled(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
  );
}

/// Which photo a gallery is showing, by its URL.
///
/// Images are never loaded in a test — the test HTTP client refuses them and
/// the initial shows instead — so the assertion is on what was asked for.
///
/// [within] picks the gallery when more than one is on screen, such as the
/// card behind an open profile sheet.
String shownPhoto(WidgetTester tester, {Finder? within}) {
  final gallery = within == null
      ? find.byType(PhotoGallery).first
      : find.descendant(of: within, matching: find.byType(PhotoGallery));
  final image = tester.widget<Image>(
    find.descendant(of: gallery, matching: find.byType(Image)),
  );
  return (image.image as NetworkImage).url;
}

/// Lets the image requests finish.
///
/// These are the first tests where the fake server hands out photo links, and
/// an `Image.network` left in flight is a pending timer when the tree goes
/// away, which fails the test. The test HTTP client answers 400 and the
/// person's initial shows; this just waits for that to happen.
Future<void> settleImages(WidgetTester tester) {
  return tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('a card is looked through by tapping its sides', (tester) async {
    await _openDiscover(tester, _server());

    expect(find.text('Ada'), findsOneWidget);
    expect(shownPhoto(tester), endsWith('p1/0.jpg'));

    await tester.tap(_labelled('Next photo'));
    await tester.pump();
    expect(shownPhoto(tester), endsWith('p1/1.jpg'));

    await tester.tap(_labelled('Next photo'));
    await tester.pump();
    expect(shownPhoto(tester), endsWith('p1/2.jpg'));

    // The last photo: tapping on stays on it rather than wrapping round, which
    // would make it impossible to tell where the album ends.
    await tester.tap(_labelled('Next photo'));
    await tester.pump();
    expect(shownPhoto(tester), endsWith('p1/2.jpg'));

    await tester.tap(_labelled('Previous photo'));
    await tester.pump();
    expect(shownPhoto(tester), endsWith('p1/1.jpg'));

    // Still on the same person: looking through photos is not swiping.
    expect(find.text('Ada'), findsOneWidget);
    await settleImages(tester);
  });

  testWidgets('the middle of a card still opens the full profile', (
    tester,
  ) async {
    final app = await _openDiscover(tester, _server());

    await tester.tap(_labelled('Open full profile'));
    await app.pumpUntilFound(find.byType(ProfileSheet));
    await tester.pump(const Duration(milliseconds: 500));

    // The sheet shows the same album, once the profile has loaded.
    final sheet = find.byType(ProfileSheet);
    await app.pumpUntil(
      () => shownPhoto(tester, within: sheet).endsWith('p1/0.jpg'),
      reason: 'the sheet shows the first photo',
    );
    await tester.tap(
      find.descendant(of: sheet, matching: _labelled('Next photo')),
    );
    await tester.pump();
    expect(shownPhoto(tester, within: sheet), endsWith('p1/1.jpg'));
    await settleImages(tester);
  });

  testWidgets('someone with one photo is shown plainly', (tester) async {
    final app = await _openDiscover(tester, _server(deck: const [_bea]));

    expect(find.text('Bea'), findsOneWidget);
    // No sides to tap and no bars along the top: there is nothing to count.
    expect(_labelled('Next photo'), findsNothing);
    expect(_labelled('Previous photo'), findsNothing);
    expect(shownPhoto(tester), endsWith('p2/0.jpg'));

    // And the middle still opens the profile.
    await tester.tap(_labelled('Open full profile'));
    await app.pumpUntilFound(find.byType(ProfileSheet));
    await settleImages(tester);
  });

  testWidgets('moving to the next person starts at their first photo', (
    tester,
  ) async {
    final app = await _openDiscover(tester, _server());

    await tester.tap(_labelled('Next photo'));
    await tester.pump();
    expect(shownPhoto(tester), endsWith('p1/1.jpg'));

    final pass = _labelled('Pass');
    await tester.ensureVisible(pass);
    await tester.pump();
    await tester.tap(pass);
    await app.pumpUntilFound(find.text('Bea'));
    // The card being passed fades out over the new one, so wait for it to go
    // rather than reading whichever of the two is first in the tree.
    await app.pumpUntilGone(find.text('Ada'));

    // Bea's first photo, not Ada's second: the count belongs to the card.
    expect(shownPhoto(tester), endsWith('p2/0.jpg'));
    await settleImages(tester);
  });
}
