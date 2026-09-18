import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo/demo_mode.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/cursor_page.dart';
import '../../../core/time/clock.dart';
import '../../matches/data/demo_inbox.dart';
import '../../safety/domain/trusted_contact.dart';
import '../domain/plan.dart';
import 'demo_plans_repository.dart';

/// The lists on the Plans screen.
enum PlansTab {
  /// Confirmed, and still ahead.
  upcoming,

  /// Sent, and waiting for an answer, from either side.
  pending,

  /// The user's own, not sent yet.
  drafts,

  /// Finished one way or another.
  history,
}

/// What a plan says: where, when, for how long, and a note. A plan names a
/// place from Kinvo's list, [venueId], or one typed in, [customLocation].
@immutable
final class PlanDetails {
  const PlanDetails({
    this.venueId,
    this.customLocation,
    this.customAddress,
    this.scheduledAt,
    this.durationMinutes,
    this.notes,
  }) : assert(
         (venueId == null) != (customLocation == null),
         'A plan names a venue or a typed place, not both.',
       );

  final String? venueId;
  final String? customLocation;
  final String? customAddress;
  final DateTime? scheduledAt;
  final int? durationMinutes;
  final String? notes;
}

/// Plans with the user's matches.
///
/// An interface because the demo shows the same screens without an account,
/// on [DemoPlansRepository]. Failures are `ApiException`s.
abstract interface class PlansRepository {
  /// One page of the plans in [tab], newest first.
  Future<CursorPage<Plan>> fetchPlans(PlansTab tab, {String? cursor});

  Future<Plan> fetchPlan(String planId);

  /// A new plan with the match [matchId]: sent to them when [send] is true,
  /// a draft only the user can see otherwise.
  Future<Plan> createPlan({
    required String matchId,
    required PlanDetails details,
    required bool send,
  });

  /// Changes the user's own draft or proposal. The other person is told about
  /// a change to a proposal.
  Future<Plan> updatePlan(String planId, PlanDetails details);

  /// Sends a draft to the other person.
  Future<Plan> sendPlan(String planId);

  Future<Plan> answer(String planId, {required bool accept});

  /// Calls off a plan that was sent. The other person is told.
  Future<Plan> cancel(String planId, {String? reason});

  /// Throws away one of the user's drafts. Nobody else ever saw it.
  Future<void> deleteDraft(String planId);

  /// How many plans wait on the user's answer.
  Future<int> fetchAwaitingAnswerCount();

  /// Emails a confirmed plan to the user's trusted contacts [contactIds].
  /// Each is told once about a plan.
  Future<PlanShare> sharePlan(String planId, List<String> contactIds);
}

/// [PlansRepository] on the Kinvo API.
final class ApiPlansRepository implements PlansRepository {
  const ApiPlansRepository(this._api);

  static const pageSize = 20;

  final ApiClient _api;

  @override
  Future<CursorPage<Plan>> fetchPlans(PlansTab tab, {String? cursor}) {
    return _api.getPage(
      '/plans',
      decodeItem: Plan.fromJson,
      cursor: cursor,
      limit: pageSize,
      query: switch (tab) {
        PlansTab.drafts => {'drafts': 'true'},
        _ => {'tab': tab.name},
      },
    );
  }

  @override
  Future<Plan> fetchPlan(String planId) {
    return _api.get(_path(planId), decode: Plan.fromJson);
  }

  @override
  Future<Plan> createPlan({
    required String matchId,
    required PlanDetails details,
    required bool send,
  }) {
    final notes = details.notes?.trim() ?? '';
    final address = details.customAddress?.trim() ?? '';
    return _api.post(
      '/plans',
      body: {
        'match_id': matchId,
        'venue_id': ?details.venueId,
        'custom_location': ?details.customLocation?.trim(),
        if (address.isNotEmpty) 'custom_address': address,
        if (details.scheduledAt case final scheduledAt?)
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'duration_minutes': ?details.durationMinutes,
        if (notes.isNotEmpty) 'notes': notes,
        'propose': send,
      },
      decode: Plan.fromJson,
    );
  }

  @override
  Future<Plan> updatePlan(String planId, PlanDetails details) {
    return _api.patch(
      _path(planId),
      // Both places are sent, one of them null, so switching between a venue
      // and a typed place clears the other. An empty string clears a text.
      body: {
        'venue_id': details.venueId,
        'custom_location': details.customLocation?.trim(),
        'custom_address': details.customAddress?.trim() ?? '',
        if (details.scheduledAt case final scheduledAt?)
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'duration_minutes': ?details.durationMinutes,
        'notes': details.notes?.trim() ?? '',
      },
      decode: Plan.fromJson,
    );
  }

  @override
  Future<Plan> sendPlan(String planId) {
    return _api.post('${_path(planId)}/propose', decode: Plan.fromJson);
  }

  @override
  Future<Plan> answer(String planId, {required bool accept}) {
    return _api.post(
      '${_path(planId)}/respond',
      body: {'accept': accept},
      decode: Plan.fromJson,
    );
  }

  @override
  Future<Plan> cancel(String planId, {String? reason}) {
    final trimmed = reason?.trim() ?? '';
    return _api.post(
      '${_path(planId)}/cancel',
      body: {if (trimmed.isNotEmpty) 'reason': trimmed},
      decode: Plan.fromJson,
    );
  }

  @override
  Future<void> deleteDraft(String planId) {
    return _api.delete(_path(planId), decode: ApiClient.ignoreData);
  }

  @override
  Future<int> fetchAwaitingAnswerCount() {
    return _api.get('/notifications/badges', decode: _readPlansCount);
  }

  @override
  Future<PlanShare> sharePlan(String planId, List<String> contactIds) {
    return _api.post(
      '${_path(planId)}/share',
      body: {
        'contact_ids': contactIds,
        // So the time in the emails reads as the user's own.
        'utc_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
      },
      decode: PlanShare.fromJson,
    );
  }

  static String _path(String planId) => '/plans/${Uri.encodeComponent(planId)}';

  static int _readPlansCount(JsonMap json) {
    if (json case {'plans': final int count} when count >= 0) return count;
    throw const FormatException('Expected a non-negative plans count.');
  }
}

/// The repository plans use: the demo's while exploring it, the API's
/// otherwise.
final plansRepositoryProvider = Provider<PlansRepository>((ref) {
  if (ref.watch(demoSessionProvider)) {
    return DemoPlansRepository(
      inbox: ref.watch(demoInboxProvider),
      clock: ref.watch(clockProvider),
    );
  }
  return ApiPlansRepository(ref.watch(apiClientProvider));
});
