import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../../core/auth/session_status.dart';
import '../../../../core/demo/demo_mode.dart';
import '../../../../core/network/api_error_code.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/paged_list.dart';
import '../../../../core/realtime/realtime_connection.dart';
import '../../../../core/realtime/realtime_providers.dart';
import '../../../chat/data/live_updates.dart';
import '../../../chat/domain/live_update.dart';
import '../../../safety/domain/trusted_contact.dart';
import '../../data/plans_repository.dart';
import '../../data/venues_repository.dart';
import '../../domain/plan.dart';
import '../../domain/venue.dart';

/// The tab open on the Plans screen.
final plansTabProvider = NotifierProvider<PlansTabController, PlansTab>(
  PlansTabController.new,
);

class PlansTabController extends Notifier<PlansTab> {
  @override
  PlansTab build() {
    // Back to the first tab whenever someone else's plans are shown.
    ref.watch(plansRepositoryProvider);
    return PlansTab.upcoming;
  }

  void select(PlansTab tab) => state = tab;
}

/// Whether [update] can change the plans the user sees. A match ending
/// closes its plans on the server.
bool _touchesPlans(LiveUpdate update) {
  return update is PlanUpdated || update is MatchEnded;
}

/// The plans in one tab of the Plans screen, newest first.
final plansListProvider = AsyncNotifierProvider.autoDispose
    .family<PlansListController, PagedList<Plan>, PlansTab>(
      PlansListController.new,
    );

class PlansListController extends AsyncNotifier<PagedList<Plan>> {
  PlansListController(this.tab);

  final PlansTab tab;

  PlansRepository get _repository => ref.read(plansRepositoryProvider);

  @override
  Future<PagedList<Plan>> build() async {
    final subscription = ref.watch(liveUpdatesProvider).stream.listen((update) {
      if (_touchesPlans(update)) ref.invalidateSelf();
    });
    ref
      ..onDispose(() => unawaited(subscription.cancel()))
      ..listen(realtimeStatusProvider, (previous, next) {
        // Changes made while the live connection was away never arrived.
        if (next == RealtimeStatus.connected &&
            previous != RealtimeStatus.connected &&
            state.hasValue) {
          ref.invalidateSelf();
        }
      })
      ..listen(appInForegroundProvider, (_, foreground) {
        // A plan's time may have passed meanwhile, moving it to History.
        if (foreground && state.hasValue) ref.invalidateSelf();
      });

    final page = await ref.watch(plansRepositoryProvider).fetchPlans(tab);
    return PagedList(
      items: page.items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
  }

  Future<void> loadMore() async {
    final list = state.value;
    final cursor = list?.nextCursor;
    if (list == null || !list.hasMore || list.isLoadingMore || cursor == null) {
      return;
    }

    state = AsyncData(
      list.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );
    try {
      final page = await _repository.fetchPlans(tab, cursor: cursor);
      if (!ref.mounted) return;
      _update((list) {
        final shown = {for (final plan in list.items) plan.id};
        return list.copyWith(
          items: [
            ...list.items,
            for (final plan in page.items)
              if (!shown.contains(plan.id)) plan,
          ],
          nextCursor: () => page.nextCursor,
          hasMore: page.hasMore,
          isLoadingMore: false,
        );
      });
    } on ApiException {
      if (!ref.mounted) return;
      _update((list) {
        return list.copyWith(isLoadingMore: false, loadMoreFailed: true);
      });
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  void _update(PagedList<Plan> Function(PagedList<Plan> list) change) {
    if (state.value case final list?) state = AsyncData(change(list));
  }
}

/// One plan, kept up to date while it's shown.
final planProvider = AsyncNotifierProvider.autoDispose
    .family<PlanController, Plan, String>(PlanController.new);

class PlanController extends AsyncNotifier<Plan> {
  PlanController(this.planId);

  final String planId;

  @override
  Future<Plan> build() async {
    final subscription = ref.watch(liveUpdatesProvider).stream.listen((update) {
      final concernsThis = switch (update) {
        PlanUpdated(:final planId) => planId == null || planId == this.planId,
        MatchEnded(:final matchId) => state.value?.matchId == matchId,
        _ => false,
      };
      if (concernsThis) unawaited(_reload());
    });
    ref
      ..onDispose(() => unawaited(subscription.cancel()))
      ..listen(realtimeStatusProvider, (previous, next) {
        if (next == RealtimeStatus.connected &&
            previous != RealtimeStatus.connected &&
            state.hasValue) {
          unawaited(_reload());
        }
      });

    return ref.watch(plansRepositoryProvider).fetchPlan(planId);
  }

  /// Reads the plan again, keeping what's shown if that fails. A plan that's
  /// gone, such as a draft deleted elsewhere, shows as gone.
  Future<void> _reload() async {
    try {
      final plan = await ref.read(plansRepositoryProvider).fetchPlan(planId);
      if (ref.mounted) state = AsyncData(plan);
    } on ApiException catch (error, stackTrace) {
      if (!ref.mounted) return;
      if (error case ApiErrorException(code: ApiErrorCode.notFound)) {
        state = AsyncError(error, stackTrace);
      }
    }
  }

  /// Shows [plan], just returned by the server for an action taken here.
  void show(Plan plan) {
    if (plan.id == planId) state = AsyncData(plan);
  }
}

/// How many plans wait on the user's answer, for the Plans tab's badge.
final plansAwaitingAnswerProvider =
    AsyncNotifierProvider<PlansAwaitingAnswerController, int>(
      PlansAwaitingAnswerController.new,
    );

class PlansAwaitingAnswerController extends AsyncNotifier<int> {
  /// How long to wait for a burst of changes to finish before counting again.
  static const settleDelay = Duration(milliseconds: 400);

  Timer? _refreshTimer;

  @override
  Future<int> build() async {
    final signedIn = ref.watch(sessionStatusProvider) is SignedIn;
    final inDemo = ref.watch(demoSessionProvider);
    final repository = ref.watch(plansRepositoryProvider);
    if (!signedIn && !inDemo) return 0;

    final subscription = ref.watch(liveUpdatesProvider).stream.listen((update) {
      if (_touchesPlans(update)) _scheduleRefresh();
    });
    ref
      ..onDispose(() {
        unawaited(subscription.cancel());
        _refreshTimer?.cancel();
      })
      ..listen(realtimeStatusProvider, (previous, next) {
        if (next == RealtimeStatus.connected &&
            previous != RealtimeStatus.connected) {
          _scheduleRefresh();
        }
      })
      ..listen(appInForegroundProvider, (_, foreground) {
        if (foreground) _scheduleRefresh();
      });

    return repository.fetchAwaitingAnswerCount();
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(settleDelay, () => unawaited(_refresh()));
  }

  Future<void> _refresh() async {
    if (!ref.mounted) return;
    try {
      final count = await ref
          .read(plansRepositoryProvider)
          .fetchAwaitingAnswerCount();
      if (ref.mounted) state = AsyncData(count);
    } on ApiException {
      // The badge keeps its last count until the next change.
    }
  }
}

/// How saving or acting on a plan turned out.
@immutable
sealed class PlanOutcome {
  const PlanOutcome();
}

final class PlanSaved extends PlanOutcome {
  const PlanSaved(this.plan);

  final Plan plan;
}

final class PlanRefused extends PlanOutcome {
  const PlanRefused(this.message, {this.fieldErrors = const {}});

  /// What to tell the user.
  final String message;

  /// The server's messages for each field it refused, keyed as the API names
  /// them, such as `scheduled_at`.
  final Map<String, List<String>> fieldErrors;
}

/// Everything the user can do to a plan, with every screen showing plans told
/// about what changed.
final planActionsProvider = Provider<PlanActions>(PlanActions.new);

final class PlanActions {
  PlanActions(this._ref);

  final Ref _ref;

  PlansRepository get _repository => _ref.read(plansRepositoryProvider);

  /// A new plan with the match [matchId]: sent now when [send] is true, kept
  /// as a draft otherwise.
  Future<PlanOutcome> create({
    required String matchId,
    required PlanDetails details,
    required bool send,
  }) {
    return _saving(
      () => _repository.createPlan(
        matchId: matchId,
        details: details,
        send: send,
      ),
    );
  }

  /// Saves changes to one of the user's plans, then sends it when [send] is
  /// true and it was a draft.
  Future<PlanOutcome> update(
    Plan plan,
    PlanDetails details, {
    bool send = false,
  }) {
    return _saving(() async {
      final saved = await _repository.updatePlan(plan.id, details);
      if (!send || saved.status != PlanStatus.draft) return saved;
      return _repository.sendPlan(saved.id);
    });
  }

  Future<PlanOutcome> send(Plan plan) {
    return _saving(() => _repository.sendPlan(plan.id));
  }

  Future<PlanOutcome> answer(Plan plan, {required bool accept}) {
    return _saving(() => _repository.answer(plan.id, accept: accept));
  }

  Future<PlanOutcome> cancel(Plan plan, {String? reason}) {
    return _saving(() => _repository.cancel(plan.id, reason: reason));
  }

  /// Emails [plan] to the trusted contacts [contactIds]. Returns how it went,
  /// or why it couldn't be sent.
  Future<({PlanShare? shared, String? error})> share(
    Plan plan,
    List<String> contactIds,
  ) async {
    final updates = _ref.read(liveUpdatesProvider);
    try {
      final shared = await _repository.sharePlan(plan.id, contactIds);
      updates.publish(PlanUpdated(planId: plan.id));
      return (shared: shared, error: null);
    } on ApiException catch (error) {
      return (shared: null, error: error.message);
    }
  }

  /// Throws the draft away. Returns why it failed, or `null` once it's gone.
  Future<String?> deleteDraft(Plan plan) async {
    final updates = _ref.read(liveUpdatesProvider);
    try {
      await _repository.deleteDraft(plan.id);
    } on ApiException catch (error) {
      // Already gone is what the user wanted.
      if (error case ApiErrorException(code: ApiErrorCode.notFound)) {
        updates.publish(PlanUpdated(planId: plan.id));
        return null;
      }
      return error.message;
    }
    updates.publish(PlanUpdated(planId: plan.id));
    return null;
  }

  Future<PlanOutcome> _saving(Future<Plan> Function() save) async {
    final updates = _ref.read(liveUpdatesProvider);
    try {
      final plan = await save();
      updates.publish(PlanUpdated(planId: plan.id));
      return PlanSaved(plan);
    } on ApiException catch (error) {
      return PlanRefused(
        error.message,
        fieldErrors: error is ApiErrorException ? error.fieldErrors : const {},
      );
    }
  }
}

/// Which places the venue list shows.
typedef VenueQuery = ({VenueCategory? category, bool savedOnly});

/// Places to meet near the user, for choosing one for a plan.
final venueListProvider = AsyncNotifierProvider.autoDispose
    .family<VenueListController, List<Venue>, VenueQuery>(
      VenueListController.new,
    );

class VenueListController extends AsyncNotifier<List<Venue>> {
  VenueListController(this.query);

  final VenueQuery query;

  VenuesRepository get _repository => ref.read(venuesRepositoryProvider);

  @override
  Future<List<Venue>> build() {
    final repository = ref.watch(venuesRepositoryProvider);
    if (query.savedOnly) return repository.fetchSaved();
    return repository.searchVenues(category: query.category);
  }

  /// Saves [venue] to the user's list, or takes it off. Shows the change at
  /// once, and puts it back if the server refuses. Returns why it failed, or
  /// `null`.
  Future<String?> toggleSaved(Venue venue) async {
    final saving = !venue.isSaved;
    _replace(venue.id, (shown) => shown.copyWith(isSaved: saving));
    try {
      if (saving) {
        await _repository.save(venue.id);
      } else {
        await _repository.unsave(venue.id);
      }
      return null;
    } on ApiException catch (error) {
      if (ref.mounted) {
        _replace(venue.id, (shown) => shown.copyWith(isSaved: !saving));
      }
      return error.message;
    }
  }

  void _replace(String venueId, Venue Function(Venue venue) change) {
    final venues = state.value;
    if (venues == null) return;
    state = AsyncData([
      for (final venue in venues) venue.id == venueId ? change(venue) : venue,
    ]);
  }
}

/// Places suited to a match's mode, to suggest in its plan.
final venueSuggestionsProvider = FutureProvider.autoDispose
    .family<List<Venue>, String>((ref, matchId) {
      return ref.watch(venuesRepositoryProvider).suggestFor(matchId);
    });
