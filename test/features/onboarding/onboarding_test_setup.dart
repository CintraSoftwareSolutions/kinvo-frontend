import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:kinvo/src/core/time/clock.dart';
import 'package:kinvo/src/features/onboarding/presentation/controllers/onboarding_controller.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_kinvo_server.dart';
import '../../helpers/test_backend.dart';

/// Onboarding, loaded for a signed-in account on [server].
final class OnboardingTest {
  OnboardingTest._(this.server, this.backend, this.container);

  final FakeKinvoServer server;
  final TestBackend backend;
  final ProviderContainer container;

  static Future<OnboardingTest> start(
    FakeKinvoServer server, {
    Clock? clock,
  }) async {
    final backend = TestBackend(respond: server.respond);
    await backend.tokenStore.write(liveSession());
    final container = backend.createContainer(clock: clock);
    final test = OnboardingTest._(server, backend, container)
      ..keepAlive(onboardingControllerProvider);
    await container.read(onboardingControllerProvider.future);
    return test;
  }

  OnboardingState get state {
    return container.read(onboardingControllerProvider).requireValue;
  }

  OnboardingController get flow {
    return container.read(onboardingControllerProvider.notifier);
  }

  /// Moves to [step] the way the user would, with Continue and Back.
  void goTo(OnboardingStep step) {
    while (state.step.index < step.index) {
      flow.next();
    }
    while (state.step.index > step.index) {
      flow.back();
    }
  }

  /// Requests made with [method] to [path], relative to the API base URL.
  Iterable<RequestOptions> requests(String method, String path) {
    return backend.adapter.requests.where(
      (r) => r.method == method && r.uri.path == '/api/v1$path',
    );
  }

  /// Keeps an auto-disposing provider alive for the rest of the test, as a
  /// screen watching it would.
  void keepAlive(ProviderListenable<Object?> provider) {
    container.listen(provider, (_, _) {});
  }
}
