import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';
import '../domain/plans.dart';

/// What is on sale, what the account is on, and — on staging, until
/// RevenueCat — buying by test purchase.
///
/// Failures are `ApiException`s.
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

/// The repository plans use.
final plansRepositoryProvider = Provider<PlansRepository>((ref) {
  return ApiPlansRepository(ref.watch(apiClientProvider));
});
