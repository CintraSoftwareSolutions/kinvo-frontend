import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kinvo/src/app.dart';
import 'package:kinvo/src/core/auth/auth_tokens.dart';
import 'package:kinvo/src/core/navigation/app_router.dart';
import 'package:kinvo/src/core/push/push_messaging.dart';
import 'package:kinvo/src/core/time/clock.dart';

import 'auth_fixtures.dart';
import 'fake_call_notifications.dart';
import 'fake_http_adapter.dart';
import 'fake_realtime_server.dart';
import 'test_backend.dart';

/// The whole app, running on in-memory storage against a fake backend.
final class AppHarness {
  AppHarness._(this._tester, this.backend);

  final WidgetTester _tester;
  final TestBackend backend;

  FakeHttpAdapter get adapter => backend.adapter;

  ProviderContainer get container {
    return ProviderScope.containerOf(_tester.element(find.byType(KinvoApp)));
  }

  GoRouter get router => container.read(appRouterProvider);

  /// Pumps frames until [finder] matches, failing after [timeout] of test time.
  ///
  /// `pumpAndSettle` can't be used while a spinner is animating.
  Future<void> pumpUntilFound(
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    const step = Duration(milliseconds: 100);
    for (var waited = Duration.zero; waited < timeout; waited += step) {
      if (finder.evaluate().isNotEmpty) return;
      await _tester.pump(step);
    }
    if (finder.evaluate().isEmpty) {
      throw TestFailure('Timed out waiting for $finder');
    }
  }

  /// Pumps frames until [finder] matches nothing, failing after [timeout] of
  /// test time. For waiting out a sheet or dialog as it closes.
  Future<void> pumpUntilGone(
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    const step = Duration(milliseconds: 100);
    for (var waited = Duration.zero; waited < timeout; waited += step) {
      if (finder.evaluate().isEmpty) return;
      await _tester.pump(step);
    }
    if (finder.evaluate().isNotEmpty) {
      throw TestFailure('Timed out waiting for $finder to go');
    }
  }

  /// Pumps frames until [condition] holds, failing after [timeout] of test
  /// time. For waiting on what the fake backend was sent, which nothing on
  /// screen shows.
  Future<void> pumpUntil(
    bool Function() condition, {
    required String reason,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    const step = Duration(milliseconds: 100);
    for (var waited = Duration.zero; waited < timeout; waited += step) {
      if (condition()) return;
      await _tester.pump(step);
    }
    if (!condition()) {
      throw TestFailure('Timed out waiting until $reason');
    }
  }

  /// Pumps frames until nothing on screen is loading, failing after
  /// [timeout] of test time.
  ///
  /// For tests that end on a screen which loads as it opens, such as
  /// Discover, so they don't finish with requests still on their way.
  Future<void> pumpUntilLoaded({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    const step = Duration(milliseconds: 100);
    final loading = find.byType(CircularProgressIndicator);
    for (var waited = Duration.zero; waited < timeout; waited += step) {
      await _tester.pump(step);
      if (loading.evaluate().isEmpty) return;
    }
    throw TestFailure('Timed out waiting for the screen to finish loading');
  }
}

/// A saved session that stays valid for the whole test.
AuthTokens liveSession() {
  return testTokens(
    '1',
    expiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
  );
}

/// Pumps [KinvoApp] on a phone-sized screen, with [savedSession] restored at
/// startup, every API request answered by [respond], and the live connection
/// served by [realtime].
Future<AppHarness> pumpKinvoApp(
  WidgetTester tester, {
  AuthTokens? savedSession,
  FakeResponder? respond,
  FakeRealtimeServer? realtime,
  PushMessaging? push,
  FakeCallNotifications? callNotifications,
  bool demoAvailable = true,
  Clock? clock,
}) async {
  tester.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final backend = TestBackend(
    respond: respond,
    realtime: realtime,
    push: push,
    callNotifications: callNotifications,
  );
  if (savedSession != null) {
    await backend.tokenStore.write(savedSession);
  }

  await tester.pumpWidget(
    ProviderScope(
      // Retries are covered by their own tests; here they would only add
      // timers.
      retry: (_, _) => null,
      overrides: backend.overrides(demoAvailable: demoAvailable, clock: clock),
      child: const KinvoApp(),
    ),
  );
  return AppHarness._(tester, backend);
}
