import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/features/calls/presentation/screens/call_screen.dart';
import 'package:kinvo/src/features/chat/presentation/screens/chat_screen.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';
import 'package:kinvo/src/features/matches/presentation/screens/matches_screen.dart';

import '../../helpers/app_harness.dart';

void main() {
  testWidgets('the demo calls a sample match, offline', (tester) async {
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

    await tester.tap(find.byTooltip('Video call'));
    await app.pumpUntilFound(find.byType(CallScreen));

    expect(find.text('Calling…'), findsOneWidget);
    expect(find.text('Sarah'), findsOneWidget);

    await tester.tap(find.text('End'));
    await app.pumpUntilGone(find.byType(CallScreen));

    // The whole demo runs on the device: a call that reached the network
    // would not be a demo.
    expect(app.adapter.requests, isEmpty);
  });
}
