import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../../core/auth/session_status.dart';
import '../../../../core/forms/form_errors.dart';
import '../../../../core/network/api_error_code.dart';
import '../../../../core/network/api_exception.dart';
import '../../../chat/data/live_updates.dart';
import '../../../chat/domain/live_update.dart';
import '../../data/plan_purchases.dart';
import '../../data/plans_repository.dart';
import '../../domain/plans.dart';

/// The account's plan, kept for the whole session.
///
/// Re-read when the server says it changed — a purchase on another phone, a
/// plan running out — and replaced directly by a purchase made here, so no
/// screen that shows the plan lags behind what was just bought.
final currentPlanProvider =
    AsyncNotifierProvider<CurrentPlanController, CurrentPlan>(
      CurrentPlanController.new,
    );

class CurrentPlanController extends AsyncNotifier<CurrentPlan> {
  @override
  Future<CurrentPlan> build() async {
    final session = ref.watch(sessionStatusProvider);

    // Nobody is signed in: there is no plan to read, and asking would be a
    // request with no session behind it.
    if (session is! SignedIn) return CurrentPlan.free;

    final updates = ref.watch(liveUpdatesProvider).stream.listen((update) {
      if (update is SubscriptionChanged) unawaited(refresh());
    });
    ref.onDispose(() => unawaited(updates.cancel()));

    return ref.watch(plansRepositoryProvider).fetchCurrent();
  }

  /// Reads the plan again. A failure keeps what is shown: a plan that was
  /// right a moment ago is a better answer than an error in its place.
  Future<void> refresh() async {
    try {
      final latest = await ref.read(plansRepositoryProvider).fetchCurrent();
      if (ref.mounted) state = AsyncData(latest);
    } on Object catch (error, stackTrace) {
      if (ref.mounted && !state.hasValue) state = AsyncError(error, stackTrace);
    }
  }

  /// Takes [plan] as the account's plan, as the server just reported it.
  void replace(CurrentPlan plan) => state = AsyncData(plan);
}

/// What is on sale.
///
/// Read fresh each time the plans are opened: prices, and what each plan
/// includes, are the server's to change between visits.
final planCatalogueProvider = FutureProvider.autoDispose<PlanCatalogue>((ref) {
  return ref.watch(plansRepositoryProvider).fetchCatalogue();
});

/// A purchase or an ending in progress, and what went wrong with the last one.
@immutable
final class PremiumActivity {
  const PremiumActivity({this.buying, this.isEnding = false, this.error});

  /// The plan being bought, while it is.
  final Plan? buying;

  final bool isEnding;

  /// What went wrong, in words, or null.
  final String? error;

  bool get isBusy => buying != null || isEnding;
}

final premiumActivityProvider =
    NotifierProvider.autoDispose<PremiumActivityController, PremiumActivity>(
      PremiumActivityController.new,
    );

class PremiumActivityController extends Notifier<PremiumActivity> {
  @override
  PremiumActivity build() => const PremiumActivity();

  /// Buys [plan] the way [purchases] sells it. Returns the account's plan
  /// afterwards, or null when it didn't happen — then the reason is in
  /// [PremiumActivity.error].
  Future<CurrentPlan?> buy(Plan plan, PlanPurchases purchases) {
    return _run(() => purchases.buy(plan), buying: plan);
  }

  /// Ends the account's test plan. Returns the plan afterwards, or null when
  /// it didn't happen.
  Future<CurrentPlan?> endTestPlan(PlanPurchases purchases) {
    return _run(purchases.endTestPlan, ending: true);
  }

  Future<CurrentPlan?> _run(
    Future<CurrentPlan> Function() action, {
    Plan? buying,
    bool ending = false,
  }) async {
    // A second tap while the first is on its way would buy twice.
    if (state.isBusy) return null;
    state = PremiumActivity(buying: buying, isEnding: ending);

    String? error;
    CurrentPlan? result;
    try {
      result = await action();
      ref.read(currentPlanProvider.notifier).replace(result);
    } on ApiException catch (failure) {
      error = switch (failure) {
        // Test purchases were switched off after the plans were shown. The
        // server's answer is the true one, so show the plans as they are now.
        ApiErrorException(code: ApiErrorCode.notFound) =>
          "Buying isn't available right now.",
        _ => saveFailureMessage(failure, field: 'product'),
      };
      if (failure case ApiErrorException(code: ApiErrorCode.notFound)) {
        ref.invalidate(planCatalogueProvider);
      }
    } on Object {
      error = unexpectedFailureMessage;
      rethrow;
    } finally {
      if (ref.mounted) state = PremiumActivity(error: error);
    }
    return result;
  }
}
