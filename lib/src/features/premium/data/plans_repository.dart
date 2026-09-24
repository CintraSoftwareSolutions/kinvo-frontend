import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo/demo_mode.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';
import '../../../core/time/clock.dart';
import '../domain/plans.dart';

/// What is on sale, what the account is on, and — on staging, until
/// RevenueCat — buying by test purchase.
///
/// An interface because the demo shows the same screens without an account,
/// on [DemoPlansRepository]. Failures are `ApiException`s.
abstract interface class PlansRepository {
  Future<PlanCatalogue> fetchCatalogue();

  Future<CurrentPlan> fetchCurrent();

  /// Starts [plan] at once with no payment taken, replacing any test plan the
  /// account holds. Only where the catalogue's purchase mode is `test`.
  Future<CurrentPlan> buyForTesting(Plan plan);

  /// Ends the account's test plan at once.
  Future<CurrentPlan> endTestPlan();
}

/// [PlansRepository] on the Kinvo API.
final class ApiPlansRepository implements PlansRepository {
  const ApiPlansRepository(this._api);

  final ApiClient _api;

  static const _testPurchase = '/subscriptions/test-purchase';

  @override
  Future<PlanCatalogue> fetchCatalogue() {
    return _api.get('/subscriptions/products', decode: PlanCatalogue.fromJson);
  }

  @override
  Future<CurrentPlan> fetchCurrent() {
    return _api.get('/subscriptions/me', decode: CurrentPlan.fromJson);
  }

  @override
  Future<CurrentPlan> buyForTesting(Plan plan) {
    return _api.post(
      _testPurchase,
      body: {'product': plan.slug},
      decode: CurrentPlan.fromJson,
    );
  }

  @override
  Future<CurrentPlan> endTestPlan() {
    return _api.delete(_testPurchase, decode: CurrentPlan.fromJson);
  }
}

/// The plans on sale in the demo: staging's catalogue, word for word, so the
/// demo sells nothing the product doesn't.
const _demoBasicFeatures = [
  'Unlimited likes',
  'Unlimited messages',
  'Filter by interests and goals',
  'Undo your last swipe',
  'Up to 5 modes at once',
  'No ads',
];

const _demoPremiumFeatures = [
  'Unlimited likes',
  'Unlimited messages',
  'See who liked you',
  'Filter by interests and goals',
  'Undo your last swipe',
  'Boost your profile',
  'Extend a match before it expires',
  'Every mode at once',
  'No ads',
];

const demoCatalogue = PlanCatalogue(
  purchaseMode: PurchaseMode.test,
  plans: [
    Plan(
      slug: 'basic_monthly',
      name: 'Kinvo Basic — Monthly',
      tier: PlanTier.basic,
      cycle: BillingCycle.monthly,
      price: Money(amountMinor: 999, currency: 'USD'),
      features: _demoBasicFeatures,
    ),
    Plan(
      slug: 'basic_yearly',
      name: 'Kinvo Basic — Yearly',
      tier: PlanTier.basic,
      cycle: BillingCycle.yearly,
      price: Money(amountMinor: 7999, currency: 'USD'),
      features: _demoBasicFeatures,
    ),
    Plan(
      slug: 'advanced_monthly',
      name: 'Kinvo Premium — Monthly',
      tier: PlanTier.premium,
      cycle: BillingCycle.monthly,
      price: Money(amountMinor: 1999, currency: 'USD'),
      features: _demoPremiumFeatures,
    ),
    Plan(
      slug: 'advanced_yearly',
      name: 'Kinvo Premium — Yearly',
      tier: PlanTier.premium,
      cycle: BillingCycle.yearly,
      price: Money(amountMinor: 15999, currency: 'USD'),
      features: _demoPremiumFeatures,
    ),
  ],
);

/// What the demo remembers about its plan, for as long as the demo lasts.
final class DemoPlans {
  DemoPlans({required this.clock});

  final Clock clock;

  CurrentPlan current = CurrentPlan.free;
}

final demoPlansProvider = Provider<DemoPlans>((ref) {
  ref.watch(demoSessionProvider);
  return DemoPlans(clock: ref.watch(clockProvider));
});

/// [PlansRepository] for the demo: plans are test plans, kept in memory, and
/// nothing is sent anywhere — as on staging, where buying is a test too.
final class DemoPlansRepository implements PlansRepository {
  const DemoPlansRepository(this._demo);

  final DemoPlans _demo;

  @override
  Future<PlanCatalogue> fetchCatalogue() async => demoCatalogue;

  @override
  Future<CurrentPlan> fetchCurrent() async => _demo.current;

  @override
  Future<CurrentPlan> buyForTesting(Plan plan) async {
    final now = _demo.clock().toUtc();
    return _demo.current = CurrentPlan(
      tier: plan.tier,
      subscription: PlanSubscription(
        productSlug: plan.slug,
        tier: plan.tier,
        cycle: plan.cycle,
        isTest: true,
        isActive: true,
        renews: false,
        periodEnd: _addMonths(now, plan.cycle.months),
      ),
    );
  }

  @override
  Future<CurrentPlan> endTestPlan() async {
    final ended = _demo.current.subscription;
    return _demo.current = CurrentPlan(
      tier: PlanTier.free,
      subscription: ended == null
          ? null
          : PlanSubscription(
              productSlug: ended.productSlug,
              tier: ended.tier,
              cycle: ended.cycle,
              isTest: ended.isTest,
              isActive: false,
              renews: false,
              periodEnd: ended.periodEnd,
            ),
    );
  }

  /// Calendar months, clamped as the server counts them: 31 January plus a
  /// month is the end of February.
  static DateTime _addMonths(DateTime from, int months) {
    final firstOfTarget = DateTime.utc(from.year, from.month + months);
    final lastDay = DateTime.utc(
      firstOfTarget.year,
      firstOfTarget.month + 1,
      0,
    ).day;
    return DateTime.utc(
      firstOfTarget.year,
      firstOfTarget.month,
      from.day < lastDay ? from.day : lastDay,
      from.hour,
      from.minute,
      from.second,
    );
  }
}

/// The repository plans use: the demo's while exploring it, the API's
/// otherwise.
final plansRepositoryProvider = Provider<PlansRepository>((ref) {
  if (ref.watch(demoSessionProvider)) {
    return DemoPlansRepository(ref.watch(demoPlansProvider));
  }
  return ApiPlansRepository(ref.watch(apiClientProvider));
});
