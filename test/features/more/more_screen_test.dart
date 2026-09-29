import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/widgets/count_badge.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';
import 'package:kinvo/src/features/home/presentation/widgets/home_bottom_nav.dart';
import 'package:kinvo/src/features/more/presentation/screens/more_screen.dart';
import 'package:kinvo/src/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:kinvo/src/features/profile/presentation/screens/profile_preview_screen.dart';
import 'package:kinvo/src/features/profile/presentation/widgets/person_photo.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_kinvo_server.dart';

/// The account hub: who is signed in, what's waiting, and the way to the rest.
void main() {
  late FakeKinvoServer server;

  setUp(() {
    server = FakeKinvoServer()
      ..completeProfile()
      ..isOnboarded = true;
  });

  Future<AppHarness> openMore(WidgetTester tester) async {
    final app = await pumpKinvoApp(
      tester,
      savedSession: liveSession(),
      respond: server.respond,
      realtime: server.realtime,
      clock: server.now,
    );
    await app.pumpUntilFound(find.byType(DiscoverScreen));
    await app.pumpUntilLoaded();
    await tester.tap(
      find.descendant(
        of: find.byType(HomeBottomNav),
        matching: find.text('More'),
      ),
    );
    await app.pumpUntilFound(find.byType(MoreScreen));
    await app.pumpUntilLoaded();
    return app;
  }

  /// The count on the Notifications row.
  Finder rowCount(String count) {
    return find.descendant(
      of: find.byType(MoreScreen),
      matching: find.descendant(
        of: find.byType(CountBadge),
        matching: find.text(count),
      ),
    );
  }

  /// The count on the More tab.
  Finder tabCount(String count) {
    return find.descendant(
      of: find.byType(HomeBottomNav),
      matching: find.text(count),
    );
  }

  String urlOf(ImageProvider provider) {
    return switch (provider) {
      ResizeImage(:final imageProvider) => urlOf(imageProvider),
      NetworkImage(:final url) => url,
      _ => '',
    };
  }

  testWidgets('shows your own photo, and View opens your profile as others '
      'see it', (tester) async {
    final app = await openMore(tester);

    final avatar = tester.widget<Image>(
      find.descendant(
        of: find.descendant(
          of: find.byType(MoreScreen),
          matching: find.byType(PersonPhoto),
        ),
        matching: find.byType(Image),
      ),
    );
    expect(urlOf(avatar.image), contains('/photo-0.jpg'));
    // Nothing left over from the prototype.
    expect(find.text('Workspace status'), findsNothing);

    await tester.tap(find.text('View'));
    await app.pumpUntilFound(find.byType(ProfilePreviewScreen));
    await app.pumpUntilLoaded();

    await tester.tap(find.byTooltip('Back'));
    await app.pumpUntilGone(find.byType(ProfilePreviewScreen));
    expect(find.byType(MoreScreen), findsOneWidget);
    // The photos' requests settle before the test ends.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('without a photo, shows your initial instead', (tester) async {
    server.photos.clear();
    await openMore(tester);

    expect(
      find.descendant(
        of: find.byType(PersonPhoto),
        matching: find.byType(Image),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(PersonPhoto), matching: find.text('S')),
      findsOneWidget,
    );
  });

  testWidgets('the Notifications row counts what is unread, as the tab does, '
      'and a notification arriving counts at once', (tester) async {
    server.addNotification(
      'new_like',
      'Someone liked you',
      'Open Kinvo to see who.',
    );
    final app = await openMore(tester);

    await app.pumpUntilFound(rowCount('1'));
    expect(tabCount('1'), findsOneWidget);

    server.notifyLive('system', 'Welcome to Kinvo', 'Say hello.');
    await app.pumpUntilFound(rowCount('2'));
    expect(tabCount('2'), findsOneWidget);

    // Once they're read, both counts go.
    await tester.tap(find.text('Notifications'));
    await app.pumpUntilFound(find.byType(NotificationsScreen));
    await app.pumpUntilLoaded();
    await tester.tap(find.text('Mark all read'));
    await app.pumpUntilGone(find.text('Mark all read'));
    await tester.tap(find.byTooltip('Back'));
    await app.pumpUntilGone(find.byType(NotificationsScreen));
    await app.pumpUntilGone(rowCount('2'));
    expect(find.byType(CountBadge), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('tells screen readers what is waiting, on the tab and the row', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    server.addNotification('system', 'Welcome to Kinvo', 'Say hello.');
    final app = await openMore(tester);
    await app.pumpUntilFound(rowCount('1'));

    expect(find.bySemanticsLabel('More, 1 new'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'^Notifications, .+, 1 new$')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 1));
    semantics.dispose();
  });
}
