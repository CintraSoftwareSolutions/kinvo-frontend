import '../../../core/network/api_error_code.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/cursor_page.dart';
import '../../../core/time/clock.dart';
import '../../discovery/data/demo_people.dart';
import '../../matches/data/demo_inbox.dart';
import '../../safety/domain/trusted_contact.dart';
import '../domain/plan.dart';
import '../domain/venue.dart';
import 'demo_venues_repository.dart';
import 'plans_repository.dart';

/// Plans for the demo: a few samples with the demo's matches, kept in memory
/// and following the server's rules.
final class DemoPlansRepository implements PlansRepository {
  DemoPlansRepository({required DemoInbox inbox, required Clock clock})
    : _inbox = inbox,
      _clock = clock {
    final today = _atHour(clock(), 0);
    _plans.addAll([
      _DemoPlan(
        id: 'demo-plan-1',
        matchId: 'sarah',
        isMine: true,
        status: PlanStatus.confirmed,
        scheduledAt: today.add(const Duration(days: 2, hours: 19)),
        durationMinutes: 90,
        venue: DemoVenuesRepository.samples.first,
        notes: 'The window seats are the best.',
      ),
      _DemoPlan(
        id: 'demo-plan-2',
        matchId: 'marcus',
        isMine: false,
        status: PlanStatus.proposed,
        scheduledAt: today.add(const Duration(days: 4, hours: 8, minutes: 30)),
        durationMinutes: 60,
        customLocation: 'Breakfast at The Wren',
        customAddress: '114 Queen Victoria Street',
        notes: 'Happy to talk through the launch plan.',
      ),
      _DemoPlan(
        id: 'demo-plan-3',
        matchId: 'emma',
        isMine: true,
        status: PlanStatus.proposed,
        scheduledAt: today.add(const Duration(days: 1, hours: 14)),
        durationMinutes: 120,
        customLocation: 'City Library, third floor',
      ),
      _DemoPlan(
        id: 'demo-plan-4',
        matchId: 'sarah',
        isMine: true,
        status: PlanStatus.draft,
        scheduledAt: today.add(const Duration(days: 6, hours: 17)),
        customLocation: 'Riverside walk',
      ),
      _DemoPlan(
        id: 'demo-plan-5',
        matchId: 'emma',
        isMine: false,
        status: PlanStatus.completed,
        scheduledAt: today.subtract(const Duration(days: 5, hours: -15)),
        durationMinutes: 60,
        venue: DemoVenuesRepository.samples[2],
      ),
    ]);
  }

  final DemoInbox _inbox;
  final Clock _clock;
  final List<_DemoPlan> _plans = [];
  int _created = 0;

  @override
  Future<CursorPage<Plan>> fetchPlans(PlansTab tab, {String? cursor}) async {
    final now = _clock();
    final items = [
      for (final plan in _visible().toList().reversed)
        if (_inTab(plan, tab, now)) _toPlan(plan, now),
    ];
    return CursorPage(
      items: items,
      nextCursor: null,
      hasMore: false,
      limit: items.length,
    );
  }

  @override
  Future<Plan> fetchPlan(String planId) async =>
      _toPlan(_find(planId), _clock());

  @override
  Future<Plan> createPlan({
    required String matchId,
    required PlanDetails details,
    required bool send,
  }) async {
    if (_inbox.find(matchId) == null) throw _notFound;
    final now = _clock();
    _checkTime(details.scheduledAt, now, sending: send);

    final plan = _DemoPlan(
      id: 'demo-plan-new-${++_created}',
      matchId: matchId,
      isMine: true,
      status: send ? PlanStatus.proposed : PlanStatus.draft,
    ).._apply(details);
    _plans.add(plan);
    return _toPlan(plan, now);
  }

  @override
  Future<Plan> updatePlan(String planId, PlanDetails details) async {
    final plan = _find(planId);
    if (!plan.isMine) throw _notFound;
    if (plan.status != PlanStatus.draft && plan.status != PlanStatus.proposed) {
      throw _refused('This plan can no longer be changed.');
    }
    final now = _clock();
    _checkTime(details.scheduledAt, now, sending: false);
    plan._apply(details);
    return _toPlan(plan, now);
  }

  @override
  Future<Plan> sendPlan(String planId) async {
    final plan = _find(planId);
    if (!plan.isMine) throw _notFound;
    if (plan.status != PlanStatus.draft) {
      throw _refused('That plan has already been sent.');
    }
    final now = _clock();
    _checkTime(plan.scheduledAt, now, sending: true);
    plan.status = PlanStatus.proposed;
    return _toPlan(plan, now);
  }

  @override
  Future<Plan> answer(String planId, {required bool accept}) async {
    final plan = _find(planId);
    final now = _clock();
    if (plan.status != PlanStatus.proposed || plan.isMine) {
      throw _refused('That plan is not awaiting your answer.');
    }
    if (accept && _hasStarted(plan, now)) {
      throw _refused('The time for that plan has passed.');
    }
    plan.status = accept ? PlanStatus.confirmed : PlanStatus.declined;
    return _toPlan(plan, now);
  }

  @override
  Future<Plan> cancel(String planId, {String? reason}) async {
    final plan = _find(planId);
    final now = _clock();
    if (plan.status == PlanStatus.draft) {
      throw _refused('That plan was never sent. Delete the draft instead.');
    }
    if (plan.status != PlanStatus.proposed &&
        plan.status != PlanStatus.confirmed) {
      throw _refused('That plan is already finished.');
    }
    plan.status = PlanStatus.cancelled;
    return _toPlan(plan, now);
  }

  @override
  Future<void> deleteDraft(String planId) async {
    final plan = _find(planId);
    if (plan.status != PlanStatus.draft || !plan.isMine) {
      throw _refused('Only a draft can be deleted.');
    }
    _plans.remove(plan);
  }

  @override
  Future<int> fetchAwaitingAnswerCount() async {
    final now = _clock();
    return _visible()
        .where((plan) => _toPlan(plan, now).awaitingMyResponse)
        .length;
  }

  @override
  Future<PlanShare> sharePlan(String planId, List<String> contactIds) async {
    final plan = _find(planId);
    if (plan.status != PlanStatus.confirmed) {
      throw _refused('Only a confirmed plan can be shared.');
    }
    // The demo emails nobody.
    return const PlanShare(shared: 0, contacts: []);
  }

  /// Plans with matches still standing. Like the server, ending a match
  /// deletes its drafts and cancels what was still ahead.
  Iterable<_DemoPlan> _visible() sync* {
    final now = _clock();
    for (final plan in _plans) {
      if (_inbox.find(plan.matchId) != null) {
        yield plan;
        continue;
      }
      if (plan.status == PlanStatus.draft) continue;
      if (plan.status == PlanStatus.proposed ||
          (plan.status == PlanStatus.confirmed && !_hasStarted(plan, now))) {
        plan.status = PlanStatus.cancelled;
      }
      yield plan;
    }
  }

  _DemoPlan _find(String planId) {
    for (final plan in _visible()) {
      if (plan.id == planId) return plan;
    }
    throw _notFound;
  }

  Plan _toPlan(_DemoPlan plan, DateTime now) {
    final person = demoPersonById(plan.matchId);
    final match = _inbox.matches.firstWhere(
      (match) => match.id == plan.matchId,
    );
    final venue = plan.venue;
    return Plan(
      id: plan.id,
      matchId: plan.matchId,
      mode: match.mode,
      user: person!.summaryAt(now),
      status: plan.status,
      scheduledAt: plan.scheduledAt,
      durationMinutes: plan.durationMinutes,
      notes: plan.notes,
      venue: venue == null
          ? null
          : PlanVenue(
              id: venue.id,
              name: venue.name,
              category: venue.category,
              address: venue.address,
            ),
      customLocation: plan.customLocation,
      customAddress: plan.customAddress,
      isMine: plan.isMine,
      awaitingMyResponse:
          plan.status == PlanStatus.proposed &&
          !plan.isMine &&
          !_hasStarted(plan, now),
      sharedWithContacts: 0,
      createdAt: now,
    );
  }

  static bool _inTab(_DemoPlan plan, PlansTab tab, DateTime now) {
    final started = _hasStarted(plan, now);
    return switch (tab) {
      PlansTab.upcoming => plan.status == PlanStatus.confirmed && !started,
      PlansTab.pending => plan.status == PlanStatus.proposed && !started,
      PlansTab.drafts => plan.status == PlanStatus.draft,
      PlansTab.history =>
        plan.status == PlanStatus.completed ||
            plan.status == PlanStatus.cancelled ||
            plan.status == PlanStatus.declined ||
            ((plan.status == PlanStatus.confirmed ||
                    plan.status == PlanStatus.proposed) &&
                started),
    };
  }

  static bool _hasStarted(_DemoPlan plan, DateTime now) {
    final scheduledAt = plan.scheduledAt;
    return scheduledAt != null && !scheduledAt.isAfter(now);
  }

  static void _checkTime(
    DateTime? scheduledAt,
    DateTime now, {
    required bool sending,
  }) {
    if (scheduledAt == null) {
      if (sending) throw _invalidTime('Set a time before proposing a plan.');
      return;
    }
    if (!scheduledAt.isAfter(now)) {
      throw _invalidTime('Pick a time in the future.');
    }
  }

  static DateTime _atHour(DateTime day, int hour) {
    return DateTime(day.year, day.month, day.day, hour);
  }

  static ApiErrorException _invalidTime(String message) {
    return ApiErrorException(
      code: ApiErrorCode.validationFailed,
      message: 'Some fields need attention.',
      statusCode: 400,
      details: {
        'scheduled_at': [message],
      },
    );
  }

  static ApiErrorException _refused(String message) {
    return ApiErrorException(
      code: ApiErrorCode.badRequest,
      message: message,
      statusCode: 400,
    );
  }

  static const _notFound = ApiErrorException(
    code: ApiErrorCode.notFound,
    message: 'We could not find that.',
    statusCode: 404,
  );
}

final class _DemoPlan {
  _DemoPlan({
    required this.id,
    required this.matchId,
    required this.isMine,
    required this.status,
    this.scheduledAt,
    this.durationMinutes,
    this.venue,
    this.customLocation,
    this.customAddress,
    this.notes,
  });

  final String id;
  final String matchId;
  final bool isMine;
  PlanStatus status;
  DateTime? scheduledAt;
  int? durationMinutes;
  Venue? venue;
  String? customLocation;
  String? customAddress;
  String? notes;

  void _apply(PlanDetails details) {
    venue = details.venueId == null
        ? null
        : DemoVenuesRepository.samples.firstWhere(
            (venue) => venue.id == details.venueId,
          );
    customLocation = details.customLocation;
    customAddress = details.customAddress;
    scheduledAt = details.scheduledAt;
    durationMinutes = details.durationMinutes;
    notes = details.notes;
  }
}
