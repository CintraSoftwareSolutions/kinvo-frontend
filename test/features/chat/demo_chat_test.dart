import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/features/chat/presentation/screens/chat_screen.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';
import 'package:kinvo/src/features/matches/presentation/screens/matches_screen.dart';

import '../../helpers/app_harness.dart';

void main() {
  testWidgets('the demo chats on sample conversations, offline', (
    tester,
  ) async {
    final app = await pumpKinvoApp(tester);
    await app.pumpUntilFound(find.text('Explore Demo'));
    await tester.tap(find.text('Explore Demo'));
    await app.pumpUntilFound(find.byType(DiscoverScreen));
    await app.pumpUntilLoaded();

    app.router.go(AppRoutes.matches);
    await app.pumpUntilFound(find.byType(MatchesScreen));
    await app.pumpUntilLoaded();

    await tester.tap(find.text('Sarah'));
    await app.pumpUntilFound(find.byType(ChatScreen));
    await app.pumpUntilLoaded();
    expect(
      find.text('Hey! Would love to check out that new café.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'Saturday at 11?');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await app.pumpUntilFound(find.textContaining('Sent'));
    expect(find.text('Saturday at 11?'), findsOneWidget);

    // The Matches tab shows it as the last message.
    await tester.tap(find.byTooltip('Back'));
    await app.pumpUntilGone(find.byType(ChatScreen));
    expect(find.text('Saturday at 11?'), findsOneWidget);

    expect(app.adapter.requests, isEmpty);
  });
}
