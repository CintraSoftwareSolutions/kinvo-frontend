import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/plans.dart';
import 'plans_repository.dart';

/// How a plan is bought, here.
///
/// One way today: a test purchase, on staging, where the plan starts at once
/// and no money is taken. RevenueCat will be a second implementation, chosen
/// in [planPurchasesProvider]. The screens talk to the premium controllers,
/// which talk to this — so when real payments arrive, neither changes.
abstract interface class PlanPurchases {
  /// Whether anything can be bought here at all.
  bool get canBuy;

  /// Whether what is bought is a test plan: no money taken, and it can be
  /// ended from the app.
  bool get sellsTestPlans;

  /// Buys [plan] and returns the account's plan afterwards.
  Future<CurrentPlan> buy(Plan plan);

  /// Ends a test plan from inside the app. A plan bought in a store is
  /// cancelled in the store, never here.
  Future<CurrentPlan> endTestPlan();
}

/// Buying by test purchase, where the server offers it.
final class TestPlanPurchases implements PlanPurchases {
  const TestPlanPurchases(this._plans);

  final PlansRepository _plans;

  @override
  bool get canBuy => true;

  @override
  bool get sellsTestPlans => true;

  @override
  Future<CurrentPlan> buy(Plan plan) => _plans.buyForTesting(plan);

  @override
  Future<CurrentPlan> endTestPlan() => _plans.endTestPlan();
}

/// Nothing can be bought yet. The plans are still shown, and say so.
final class UnavailablePlanPurchases implements PlanPurchases {
  const UnavailablePlanPurchases();

  @override
  bool get canBuy => false;

  @override
  bool get sellsTestPlans => false;

  @override
  Future<CurrentPlan> buy(Plan plan) async {
    throw StateError('Buying is not available here yet.');
  }

  @override
  Future<CurrentPlan> endTestPlan() async {
    throw StateError('There is no test plan to end here.');
  }
}

/// The way to buy for [PurchaseMode] — the one the server's catalogue names.
final planPurchasesProvider = Provider.family<PlanPurchases, PurchaseMode>((
  ref,
  mode,
) {
  return switch (mode) {
    PurchaseMode.test => TestPlanPurchases(ref.watch(plansRepositoryProvider)),
    PurchaseMode.none => const UnavailablePlanPurchases(),
  };
});
