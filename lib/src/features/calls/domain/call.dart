import 'package:flutter/foundation.dart';

import '../../../core/network/api_envelope.dart';
import '../../profile/domain/user_summary.dart';

/// Where a call stands.
///
/// The server decides this, including whether a call that is still marked
/// ringing has in fact rung out: it answers `missed` once a minute has passed.
/// The app never works that out for itself, or two phones would disagree about
/// whether a call is still worth answering.
enum CallStatus {
  /// Started, and waiting for the other person to pick up.
  ringing('ringing'),

  /// Answered. Both people are in the room.
  active('active'),

  /// Finished normally, or closed by the server after both apps vanished.
  ended('ended'),

  /// The other person refused it.
  declined('declined'),

  /// Nobody answered in time.
  missed('missed'),

  /// A status added to the server after this version of the app.
  unknown('');

  const CallStatus(this.wireValue);

  /// Its name in the API.
  final String wireValue;

  static CallStatus fromWireValue(String value) {
    for (final status in values) {
      if (status != unknown && status.wireValue == value) return status;
    }
    return unknown;
  }

  /// Whether there is still something to join or to hang up.
  bool get isLive => this == ringing || this == active;
}

/// The room to join, and the credential that opens it.
///
/// Both come from the server together. A token names one room and expires
/// within the hour; the app asks for a new one when it reconnects rather than
/// holding one open.
@immutable
final class CallVideo {
  const CallVideo({
    required this.roomName,
    required this.token,
    required this.serverUrl,
    required this.expiresAt,
  });

  factory CallVideo.fromJson(JsonMap json) {
    if (json case {
      'room_name': final String roomName,
      'token': final String token,
      'server_url': final String? serverUrl,
      'expires_at': final String expiresAt,
    } when roomName.isNotEmpty && token.isNotEmpty) {
      final expires = DateTime.tryParse(expiresAt);
      if (expires != null) {
        return CallVideo(
          roomName: roomName,
          token: token,
          serverUrl: serverUrl == null ? null : Uri.tryParse(serverUrl),
          expiresAt: expires,
        );
      }
    }
    throw const FormatException(
      'Expected video with room_name, token, server_url and expires_at.',
    );
  }

  final String roomName;
  final String token;

  /// Where to connect, or null when the server has no video service set up.
  ///
  /// Null is an answer, not a failure: the call still rings, is answered and
  /// ends, and the screen says there is no picture or sound here. Staging runs
  /// this way.
  final Uri? serverUrl;

  final DateTime expiresAt;

  /// Whether this call can carry picture and sound at all.
  bool get isConnectable => serverUrl != null;
}

/// A call, as the server describes it.
@immutable
final class Call {
  const Call({
    required this.id,
    required this.matchId,
    required this.mode,
    required this.status,
    required this.isInitiator,
    required this.otherUser,
    required this.startedAt,
    required this.answeredAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.createdAt,
    this.video,
  });

  factory Call.fromJson(JsonMap json) {
    if (json case {
      'id': final String id,
      'match_id': final String matchId,
      'mode': final String mode,
      'status': final String status,
      'is_initiator': final bool isInitiator,
      'other_user': final JsonMap otherUser,
      'created_at': final String createdAt,
    } when id.isNotEmpty) {
      final created = DateTime.tryParse(createdAt);
      if (created != null) {
        return Call(
          id: id,
          matchId: matchId,
          mode: mode,
          status: CallStatus.fromWireValue(status),
          isInitiator: isInitiator,
          otherUser: UserSummary.fromJson(otherUser),
          startedAt: _time(json['started_at']),
          answeredAt: _time(json['answered_at']),
          endedAt: _time(json['ended_at']),
          durationSeconds: json['duration_seconds'] as int?,
          createdAt: created,
          // History carries no token: a finished call has nothing to join.
          video: switch (json['video']) {
            final JsonMap video => CallVideo.fromJson(video),
            _ => null,
          },
        );
      }
    }
    throw const FormatException(
      'Expected a call with id, match_id, status and other_user.',
    );
  }

  static DateTime? _time(Object? value) {
    return value is String ? DateTime.tryParse(value) : null;
  }

  final String id;
  final String matchId;
  final String mode;
  final CallStatus status;

  /// True for the person who started it. The two sides show different screens
  /// while it rings.
  final bool isInitiator;

  final UserSummary otherUser;
  final DateTime? startedAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;

  /// How long the two were connected, or null when nobody answered. Zero would
  /// read as a call that connected in silence.
  final int? durationSeconds;

  final DateTime createdAt;
  final CallVideo? video;

  Call copyWith({CallStatus? status, CallVideo? video, int? durationSeconds}) {
    return Call(
      id: id,
      matchId: matchId,
      mode: mode,
      status: status ?? this.status,
      isInitiator: isInitiator,
      otherUser: otherUser,
      startedAt: startedAt,
      answeredAt: answeredAt,
      endedAt: endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      createdAt: createdAt,
      video: video ?? this.video,
    );
  }
}

/// What a person can reach for during a call (spec §5.7).
enum CallSafetyAction {
  /// Records a concern. The call carries on.
  flag('flag'),

  /// Ends the call and files a report in one step, for someone who wants out
  /// now and cannot write an explanation first.
  endAndReport('end_and_report'),

  /// Emails the user's trusted contacts that the call is going on.
  sendLiveUpdate('send_live_update');

  const CallSafetyAction(this.wireValue);

  final String wireValue;
}

/// What the server did about a safety action.
///
/// It says nothing about whether trusted contacts were reached: that arrives
/// as a notification of its own, which names who was emailed and who was not.
/// Reporting it twice would let the two disagree.
@immutable
final class CallSafetyResult {
  const CallSafetyResult({
    required this.callId,
    required this.action,
    required this.callStatus,
    required this.reportId,
  });

  factory CallSafetyResult.fromJson(JsonMap json) {
    if (json case {
      'call_id': final String callId,
      'action': final String action,
      'call_status': final String callStatus,
    } when callId.isNotEmpty) {
      return CallSafetyResult(
        callId: callId,
        action: action,
        callStatus: CallStatus.fromWireValue(callStatus),
        reportId: json['report_id'] as String?,
      );
    }
    throw const FormatException(
      'Expected a safety result with call_id, action and call_status.',
    );
  }

  final String callId;
  final String action;
  final CallStatus callStatus;

  /// The report this action filed, for `end_and_report` only.
  final String? reportId;

  /// Whether the call is over because of it.
  bool get callEnded => !callStatus.isLive;
}
