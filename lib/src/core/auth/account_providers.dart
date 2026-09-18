import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/api_client_provider.dart';
import 'account.dart';
import 'auth_providers.dart';
import 'session_status.dart';

/// The signed-in user's account.
final class AccountRepository {
  const AccountRepository(this._api);

  final ApiClient _api;

  Future<Account> fetchCurrentAccount() {
    return _api.get('/auth/me', decode: Account.fromJson);
  }

  /// Permanently deletes the account and erases its personal data. The server
  /// ends every session of the account, on every device.
  ///
  /// Safe to retry: deleting an account that's already deleted succeeds.
  Future<void> deleteAccount() {
    return _api.delete('/users/me', decode: ApiClient.ignoreData);
  }
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(apiClientProvider)),
);

/// The signed-in user's account, or `null` without a session.
///
/// Loaded whenever a session starts. Invalidate it after anything that changes
/// what it reports, such as finishing onboarding.
final currentAccountProvider = FutureProvider<Account?>((ref) async {
  final session = ref.watch(sessionStatusProvider);
  if (session is! SignedIn) return null;
  return ref.watch(accountRepositoryProvider).fetchCurrentAccount();
});
