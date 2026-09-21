import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/features/calls/domain/call.dart';

Map<String, Object?> _call({
  Object? status = 'ringing',
  Object? kind = _absent,
  Object? video = _absent,
  Object? durationSeconds,
}) {
  return {
    'id': 'call-1',
    'match_id': 'match-1',
    'mode': 'dating',
    if (kind != _absent) 'kind': kind,
    'status': status,
    'is_initiator': true,
    'other_user': {
      'id': 'p1',
      'display_name': 'Sam',
      'age': 29,
      'primary_photo_url': null,
      'is_verified': false,
      'is_premium': false,
      'is_online': true,
      'last_active_at': null,
    },
    'started_at': '2026-09-21T10:00:00.000Z',
    'answered_at': null,
    'ended_at': null,
    'duration_seconds': durationSeconds,
    'created_at': '2026-09-21T10:00:00.000Z',
    if (video != _absent) 'video': video,
  };
}

const _absent = Object();

const _video = {
  'room_name': 'kinvo-call-1',
  'token': 'token-value',
  'server_url': 'wss://kinvo.livekit.cloud',
  'expires_at': '2026-09-21T11:00:00.000Z',
};

void main() {
  group('a call', () {
    test('is read from the API', () {
      final call = Call.fromJson(_call(video: _video));

      expect(call.id, 'call-1');
      expect(call.status, CallStatus.ringing);
      expect(call.isInitiator, isTrue);
      expect(call.otherUser.displayName, 'Sam');
      expect(call.video?.roomName, 'kinvo-call-1');
      expect(call.video?.serverUrl, Uri.parse('wss://kinvo.livekit.cloud'));
      expect(call.video?.isConnectable, isTrue);
      // No kind from a server that predates voice calls means it is a video
      // call, which is what every call was then.
      expect(call.kind, CallKind.video);
    });

    test('is a voice call when the server says so', () {
      final call = Call.fromJson(_call(kind: 'audio'));

      expect(call.kind, CallKind.audio);
      expect(call.kind.startsWithCamera, isFalse);
    });

    test('of a kind this app does not know yet opens the camera', () {
      // The safe way round: a picture can be turned off, and a call with no
      // picture at all would look broken.
      final call = Call.fromJson(_call(kind: 'hologram'));

      expect(call.kind, CallKind.unknown);
      expect(call.kind.startsWithCamera, isTrue);
    });

    test('from history carries no token, because there is nothing to join', () {
      final call = Call.fromJson(_call(status: 'ended', durationSeconds: 312));

      expect(call.video, isNull);
      expect(call.status, CallStatus.ended);
      expect(call.durationSeconds, 312);
      expect(call.status.isLive, isFalse);
    });

    test('with no media server says so rather than looking connectable', () {
      final call = Call.fromJson(_call(video: {..._video, 'server_url': null}));

      // The call still rings, is answered and ends; only the picture is
      // missing, and the screen says which.
      expect(call.video, isNotNull);
      expect(call.video!.serverUrl, isNull);
      expect(call.video!.isConnectable, isFalse);
    });

    test('of a status this app does not know yet is still read', () {
      final call = Call.fromJson(_call(status: 'transferred'));

      expect(call.status, CallStatus.unknown);
      expect(call.status.isLive, isFalse);
    });

    test('is refused when malformed', () {
      expect(
        () => Call.fromJson(_call()..remove('other_user')),
        throwsFormatException,
      );
      expect(
        () => Call.fromJson(_call(video: {'token': 'only-a-token'})),
        throwsFormatException,
      );
    });
  });

  test('a safety result says whether the call is over', () {
    final ended = CallSafetyResult.fromJson(const {
      'call_id': 'call-1',
      'action': 'end_and_report',
      'call_status': 'ended',
      'report_id': 'report-1',
    });

    expect(ended.callEnded, isTrue);
    expect(ended.reportId, 'report-1');

    final flagged = CallSafetyResult.fromJson(const {
      'call_id': 'call-1',
      'action': 'flag',
      'call_status': 'active',
      'report_id': null,
    });

    expect(flagged.callEnded, isFalse);
    expect(flagged.reportId, isNull);
  });
}
