import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo/demo_mode.dart';
import '../../../core/network/api_error_code.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/cursor_page.dart';
import '../../../core/time/clock.dart';
import '../../discovery/data/demo_people.dart';
import '../../matches/data/demo_inbox.dart';
import '../domain/call.dart';
import 'calls_repository.dart';

/// Calls for the demo: kept in memory, following the server's rules.
///
/// The demo never reaches a media server, so every call here carries a null
/// `server_url` — the same answer a real server gives when video is not set
/// up. The call screen shows its own picture-less state for both, so the demo
/// exercises the real path rather than a second one written for it.
final class DemoCallsRepository implements CallsRepository {
  DemoCallsRepository({required DemoInbox inbox, required Clock clock})
    : _inbox = inbox,
      _clock = clock {
    // One call in history, so the list is not empty the first time it opens.
    _calls.add(
      _DemoCall(
        id: 'demo-call-1',
        matchId: 'marcus',
        mode: 'networking',
        isInitiator: false,
        status: CallStatus.ended,
        createdAt: _clock().subtract(const Duration(days: 1, minutes: 12)),
        answeredAt: _clock().subtract(const Duration(days: 1, minutes: 11)),
        endedAt: _clock().subtract(const Duration(days: 1)),
        durationSeconds: 11 * 60,
      ),
    );
  }

  final DemoInbox _inbox;
  final Clock _clock;
  final List<_DemoCall> _calls = [];

  @override
  Future<Call> start(String matchId) async {
    final match = _inbox.find(matchId);
    if (match == null) throw _noMatch;

    // Same rule as the server: one live call to a match, not two rooms.
    for (final call in _calls) {
      if (call.matchId == matchId && call.status.isLive) {
        return _view(call);
      }
    }

    final call = _DemoCall(
      id: 'demo-call-${_calls.length + 1}',
      matchId: matchId,
      mode: match.mode,
      isInitiator: true,
      status: CallStatus.ringing,
      createdAt: _clock(),
    );
    _calls.add(call);
    return _view(call);
  }

  @override
  Future<Call> answer(String callId) async {
    final call = _find(callId);
    if (call.status != CallStatus.ringing) throw _notRinging;
    call.status = CallStatus.active;
    call.answeredAt = _clock();
    return _view(call);
  }

  @override
  Future<Call> decline(String callId) async {
    final call = _find(callId);
    if (call.status != CallStatus.ringing) throw _notRinging;
    call.status = CallStatus.declined;
    call.endedAt = _clock();
    return _view(call);
  }

  @override
  Future<Call> end(String callId) async {
    final call = _find(callId);
    // Idempotent, like the server's: both sides hang up.
    if (call.status.isLive) {
      final answeredAt = call.answeredAt;
      call.status = answeredAt == null ? CallStatus.missed : CallStatus.ended;
      call.endedAt = _clock();
      call.durationSeconds = answeredAt == null
          ? null
          : _clock().difference(answeredAt).inSeconds;
    }
    return _view(call);
  }

  @override
  Future<Call> refreshToken(String callId) async {
    final call = _find(callId);
    if (!call.status.isLive) throw _notLive;
    return _view(call);
  }

  @override
  Future<CursorPage<Call>> fetchHistory({String? cursor}) async {
    final ordered = [..._calls]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return CursorPage(
      items: [for (final call in ordered) _view(call)],
      nextCursor: null,
      hasMore: false,
      limit: ApiCallsRepository.pageSize,
    );
  }

  @override
  Future<CallSafetyResult> recordSafetyAction(
    String callId,
    CallSafetyAction action, {
    String? note,
  }) async {
    final call = _find(callId);

    if (action == CallSafetyAction.endAndReport) {
      await end(callId);
    }

    return CallSafetyResult(
      callId: call.id,
      action: action.wireValue,
      callStatus: call.status,
      reportId: action == CallSafetyAction.endAndReport ? 'demo-report' : null,
    );
  }

  _DemoCall _find(String callId) {
    for (final call in _calls) {
      if (call.id == callId) return call;
    }
    throw _noCall;
  }

  Call _view(_DemoCall call) {
    final person = demoPersonById(call.matchId);
    if (person == null) throw _noMatch;

    return Call(
      id: call.id,
      matchId: call.matchId,
      mode: call.mode,
      status: call.status,
      isInitiator: call.isInitiator,
      otherUser: person.summaryAt(_clock()),
      startedAt: call.createdAt,
      answeredAt: call.answeredAt,
      endedAt: call.endedAt,
      durationSeconds: call.durationSeconds,
      createdAt: call.createdAt,
      video: call.status.isLive
          ? CallVideo(
              roomName: 'kinvo-call-${call.id}',
              token: 'demo-token-not-a-jwt',
              serverUrl: null,
              expiresAt: _clock().add(const Duration(hours: 1)),
            )
          : null,
    );
  }

  static const _noMatch = ApiErrorException(
    code: ApiErrorCode.notFound,
    message: 'That match does not exist.',
    statusCode: 404,
  );

  static const _noCall = ApiErrorException(
    code: ApiErrorCode.notFound,
    message: 'That call does not exist.',
    statusCode: 404,
  );

  static const _notRinging = ApiErrorException(
    code: ApiErrorCode.conflict,
    message: 'That call is no longer ringing.',
    statusCode: 409,
  );

  static const _notLive = ApiErrorException(
    code: ApiErrorCode.conflict,
    message: 'That call is not live.',
    statusCode: 409,
  );
}

/// One demo call. Mutable, because the demo's calls change as they are
/// answered and ended.
final class _DemoCall {
  _DemoCall({
    required this.id,
    required this.matchId,
    required this.mode,
    required this.isInitiator,
    required this.status,
    required this.createdAt,
    this.answeredAt,
    this.endedAt,
    this.durationSeconds,
  });

  final String id;
  final String matchId;
  final String mode;
  final bool isInitiator;
  final DateTime createdAt;

  CallStatus status;
  DateTime? answeredAt;
  DateTime? endedAt;
  int? durationSeconds;
}

/// The demo's calls, started afresh each time the demo is.
final demoCallsRepositoryProvider = Provider<DemoCallsRepository>((ref) {
  ref.watch(demoSessionProvider);
  return DemoCallsRepository(
    inbox: ref.watch(demoInboxProvider),
    clock: ref.watch(clockProvider),
  );
});
