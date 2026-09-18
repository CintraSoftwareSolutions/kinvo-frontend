import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';
import '../../../core/time/calendar_date.dart';
import '../domain/onboarding_status.dart';

/// The backend's onboarding checklist, and finishing it.
final class OnboardingRepository {
  const OnboardingRepository(this._api);

  final ApiClient _api;

  Future<OnboardingStatus> fetchStatus() {
    return _api.get('/onboarding', decode: OnboardingStatus.fromJson);
  }

  /// Sets the date of birth of an account that has none, such as one made
  /// with a social sign-in. It can't be changed afterwards.
  Future<void> setDateOfBirth(CalendarDate dateOfBirth) {
    return _api.post(
      '/onboarding/date-of-birth',
      body: {'date_of_birth': dateOfBirth.toIsoString()},
      decode: ApiClient.ignoreData,
    );
  }

  /// Finishes onboarding, which lets the account into the app. Safe to repeat.
  ///
  /// Fails with `ONBOARDING_INCOMPLETE`, listing what's missing in its
  /// details, while any requirement is unmet.
  Future<void> complete() {
    return _api.post('/onboarding/complete', decode: ApiClient.ignoreData);
  }
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepository(ref.watch(apiClientProvider)),
);
