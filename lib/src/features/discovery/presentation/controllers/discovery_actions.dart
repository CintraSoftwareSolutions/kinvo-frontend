import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/entitlements/paywall.dart';
import '../../../../core/network/api_exception.dart';
import '../../../modes/domain/mode_filters.dart';
import '../../../profile/domain/public_profile.dart';
import '../../data/discovery_repository.dart';
import '../../domain/deck_stats.dart';
import 'deck_controller.dart';
import 'discovery_modes_controller.dart';

/// How starting a boost turned out.
@immutable
sealed class BoostOutcome {
  const BoostOutcome();
}

final class BoostStarted extends BoostOutcome {
  const BoostStarted(this.boost);

  final ActiveBoost boost;
}

final class BoostNeedsUpgrade extends BoostOutcome {
  const BoostNeedsUpgrade(this.paywall);

  final Paywall paywall;
}

/// Already running, or it didn't work. [message] says which.
final class BoostFailed extends BoostOutcome {
  const BoostFailed(this.message);

  final String message;
}

/// Starting a boost in the mode given. The state says whether one is being
/// started.
final boostControllerProvider = NotifierProvider.autoDispose
    .family<BoostController, bool, String>(BoostController.new);

class BoostController extends Notifier<bool> {
  BoostController(this.mode);

  final String mode;

  @override
  bool build() => false;

  Future<BoostOutcome?> start() async {
    if (state) return null;
    state = true;
    try {
      final boost = await ref
          .read(discoveryRepositoryProvider)
          .startBoost(mode);
      ref.invalidate(deckStatsProvider(mode));
      return BoostStarted(boost);
    } on ApiException catch (error) {
      if (Paywall.fromError(error) case final paywall?) {
        return BoostNeedsUpgrade(paywall);
      }
      // A boost already running shows up in the stats read again.
      ref.invalidate(deckStatsProvider(mode));
      return BoostFailed(error.message);
    } finally {
      if (ref.mounted) state = false;
    }
  }
}

/// The filters sheet for one mode: what's saved, what's being changed, and
/// whether saving is under way.
@immutable
final class FiltersForm {
  const FiltersForm({
    required this.saved,
    required this.draft,
    this.isSaving = false,
    this.error,
  });

  final ModeFilters saved;
  final ModeFilters draft;
  final bool isSaving;

  /// Why the last save failed.
  final String? error;

  bool get hasChanges => draft != saved;

  FiltersForm copyWith({
    ModeFilters? saved,
    ModeFilters? draft,
    bool? isSaving,
    ValueGetter<String?>? error,
  }) {
    return FiltersForm(
      saved: saved ?? this.saved,
      draft: draft ?? this.draft,
      isSaving: isSaving ?? this.isSaving,
      error: error == null ? this.error : error(),
    );
  }
}

/// The filters sheet for a mode, starting from the filters it has saved.
final filtersFormProvider = NotifierProvider.autoDispose
    .family<FiltersFormController, FiltersForm, (String, ModeFilters)>(
      FiltersFormController.new,
    );

class FiltersFormController extends Notifier<FiltersForm> {
  FiltersFormController(this.args);

  /// The mode, by its API name, and the filters it has saved.
  final (String, ModeFilters) args;

  @override
  FiltersForm build() => FiltersForm(saved: args.$2, draft: args.$2);

  void setRadiusMetres(int metres) => _edit(radiusMetres: metres);

  void setAgeRange(int minAge, int maxAge) {
    _edit(minAge: minAge, maxAge: maxAge);
  }

  void setVerifiedOnly(bool verifiedOnly) => _edit(verifiedOnly: verifiedOnly);

  void _edit({
    int? minAge,
    int? maxAge,
    int? radiusMetres,
    bool? verifiedOnly,
  }) {
    if (state.isSaving) return;
    state = state.copyWith(
      draft: state.draft.copyWith(
        minAge: minAge,
        maxAge: maxAge,
        radiusMetres: radiusMetres,
        verifiedOnly: verifiedOnly,
      ),
      error: () => null,
    );
  }

  /// Saves the changes. Returns whether they were saved, or there were none.
  ///
  /// The deck is read again afterwards: the server rebuilds it from the new
  /// filters.
  Future<bool> save() async {
    if (state.isSaving) return false;
    if (!state.hasChanges) return true;

    final mode = args.$1;
    state = state.copyWith(isSaving: true, error: () => null);
    try {
      final saved = await ref
          .read(discoveryRepositoryProvider)
          .saveFilters(mode, state.draft);
      ref
        ..invalidate(discoveryModesProvider)
        ..invalidate(deckControllerProvider(mode))
        ..invalidate(deckStatsProvider(mode));
      if (ref.mounted) {
        state = state.copyWith(saved: saved, draft: saved, isSaving: false);
      }
      return true;
    } on ApiException catch (error) {
      if (ref.mounted) {
        state = state.copyWith(isSaving: false, error: () => error.message);
      }
      return false;
    }
  }
}

/// Someone's full profile, by their user id.
final publicProfileProvider = FutureProvider.autoDispose
    .family<PublicProfile, String>(
      (ref, userId) =>
          ref.watch(discoveryRepositoryProvider).fetchProfile(userId),
    );
