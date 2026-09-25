import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/auth/auth_providers.dart';
import 'package:kinvo/src/core/realtime/realtime_providers.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';
import 'package:kinvo/src/features/onboarding/presentation/screens/onboarding_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_kinvo_server.dart';

FakeKinvoServer _onboarded() {
  return FakeKinvoServer()
    ..completeProfile()
    ..isOnboarded = true;
}

/// Moves the app through each lifecycle state to [target], as the platform
/// reports them.
Future<void> _lifecycle(
  WidgetTester tester,
  List<AppLifecycleState> states,
) async {
  for (final state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
    await tester.pump();
  }
}

void main() {
  testWidgets('connects once signed in to an account that is set up, and '
      'closes on signing out', (tester) async {
    final server = _onboarded();
    final app = await pumpKinvoApp(
      tester,
      savedSession: liveSession(),
      respond: server.respond,
      realtime: server.realtime,
    );
    await app.pumpUntilFound(find.byType(DiscoverScreen));
    await app.pumpUntilLoaded();

    expect(server.realtime.isConnected, isTrue);
    expect(server.realtime.attempts, ['access-1']);

    // Awaiting it here would stall: revoking waits on timers, and time only
    // moves while frames are pumped.
    unawaited(app.container.read(sessionManagerProvider).signOut());
    await app.pumpUntilFound(find.text('Create Account'));

    expect(server.realtime.isConnected, isFalse);
  });

  testWidgets('waits until onboarding is finished', (tester) async {
    final server = FakeKinvoServer();
    final app = await pumpKinvoApp(
      tester,
      savedSession: liveSession(),
      respond: server.respond,
      realtime: server.realtime,
    );
    await app.pumpUntilFound(find.byType(OnboardingScreen));
    await app.pumpUntilLoaded();

    expect(server.realtime.attempts, isEmpty);
  });

  testWidgets('closes a while after the app leaves the screen, and opens '
      'again when it comes back', (tester) async {
    final server = _onboarded();
    final app = await pumpKinvoApp(
      tester,
      savedSession: liveSession(),
      respond: server.respond,
      realtime: server.realtime,
    );
    await app.pumpUntilFound(find.byType(DiscoverScreen));
    await app.pumpUntilLoaded();
    expect(server.realtime.isConnected, isTrue);

    await _lifecycle(tester, const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    // A quick trip to the photo picker keeps it.
    await tester.pump(realtimeBackgroundGrace - const Duration(seconds: 1));
    expect(server.realtime.isConnected, isTrue);

    await tester.pump(const Duration(seconds: 2));
    expect(server.realtime.isConnected, isFalse);

    await _lifecycle(tester, const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    expect(server.realtime.isConnected, isTrue);
    expect(server.realtime.attempts, hasLength(2));
  });
}
