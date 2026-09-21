import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo/demo_mode.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';
import '../../../core/network/cursor_page.dart';
import '../domain/call.dart';
import 'demo_calls_repository.dart';

/// Video calls with a match.
///
/// An interface because the demo shows the same screens without an account, on
/// [DemoCallsRepository]. Failures are `ApiException`s.
abstract interface class CallsRepository {
  /// Rings the other person in [matchId], and returns the call with a token.
  ///
  /// Starting a call names a MATCH, never a room: the server decides which
  /// room, so a token can never be asked for on a call the caller is not in.
  /// Calling a match that is already in a live call returns that call, rather
  /// than putting the two people in different rooms — with the kind it already
  /// had, not the one just asked for.
  ///
  /// [kind] is what the call starts as. The server stores it so the other
  /// phone knows whether to open its camera when it answers.
  Future<Call> start(String matchId, {CallKind kind = CallKind.video});

  /// Picks up a call that is ringing. Only the person who did not start it
  /// may, and only while it still rings.
  Future<Call> answer(String callId);

  /// Refuses a call that is ringing.
  Future<Call> decline(String callId);

  /// Hangs up. Safe to send twice: both apps send it, and the second is not an
  /// error the user should see.
  Future<Call> end(String callId);

  /// A fresh token for a live call, for reconnecting or outstaying the old
  /// one. The server re-checks permission each time, so someone blocked
  /// mid-call cannot rejoin.
  Future<Call> refreshToken(String callId);

  /// Call history, newest first.
  Future<CursorPage<Call>> fetchHistory({String? cursor});

  /// Records an in-call safety action. [note] is optional on purpose: someone
  /// reaching for this mid-call cannot write an explanation.
  Future<CallSafetyResult> recordSafetyAction(
    String callId,
    CallSafetyAction action, {
    String? note,
  });
}

/// [CallsRepository] on the Kinvo API.
final class ApiCallsRepository implements CallsRepository {
  const ApiCallsRepository(this._api);

  static const pageSize = 20;

  final ApiClient _api;

  @override
  Future<Call> start(String matchId, {CallKind kind = CallKind.video}) {
    return _api.post(
      '/calls',
      body: {'match_id': matchId, 'kind': kind.wireValue},
      decode: _call,
    );
  }

  @override
  Future<Call> answer(String callId) {
    return _api.post('${_path(callId)}/answer', decode: _call);
  }

  @override
  Future<Call> decline(String callId) {
    return _api.post('${_path(callId)}/decline', decode: _call);
  }

  @override
  Future<Call> end(String callId) {
    return _api.post('${_path(callId)}/end', decode: _call);
  }

  @override
  Future<Call> refreshToken(String callId) {
    return _api.get('${_path(callId)}/token', decode: _call);
  }

  @override
  Future<CursorPage<Call>> fetchHistory({String? cursor}) {
    return _api.getPage(
      '/calls',
      decodeItem: Call.fromJson,
      cursor: cursor,
      limit: pageSize,
    );
  }

  @override
  Future<CallSafetyResult> recordSafetyAction(
    String callId,
    CallSafetyAction action, {
    String? note,
  }) {
    final trimmed = note?.trim() ?? '';
    return _api.post(
      '${_path(callId)}/safety',
      body: {
        'action': action.wireValue,
        if (trimmed.isNotEmpty) 'note': trimmed,
      },
      decode: CallSafetyResult.fromJson,
    );
  }

  static String _path(String callId) => '/calls/${Uri.encodeComponent(callId)}';

  /// Every call endpoint answers with the call under a `call` key.
  static Call _call(Map<String, Object?> json) {
    if (json['call'] case final Map<String, Object?> call) {
      return Call.fromJson(call);
    }
    throw const FormatException('Expected a call.');
  }
}

/// The repository for the current session: the API when signed in, the demo's
/// fake one in a demo session.
final callsRepositoryProvider = Provider<CallsRepository>((ref) {
  if (ref.watch(demoSessionProvider)) {
    return ref.watch(demoCallsRepositoryProvider);
  }
  return ApiCallsRepository(ref.watch(apiClientProvider));
});
