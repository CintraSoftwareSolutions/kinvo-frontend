import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'call_media.dart';

/// [CallMedia] on LiveKit.
///
/// THE ONLY FILE IN THE APP THAT KNOWS WHICH VIDEO SERVICE IS BEHIND A CALL,
/// mirroring `video.provider.ts` on the server. The server was moved from
/// Twilio to LiveKit because Twilio publishes no Flutter SDK; if it moves
/// again, this file and its counterpart are the change.
///
/// The token and the address both come from the server, per call. Nothing here
/// picks a room: a room name chosen by a client is how someone joins a call
/// they were never invited to.
final class LiveKitCallMedia extends ChangeNotifier implements CallMedia {
  LiveKitCallMedia();

  /// Adaptive stream and dynacast both cut what is sent to what is actually
  /// being displayed. On a phone with a metered connection that is the
  /// difference between a call that holds and one that stutters.
  final lk.Room _room = lk.Room(
    roomOptions: const lk.RoomOptions(adaptiveStream: true, dynacast: true),
  );

  CallMediaPhase _phase = CallMediaPhase.idle;
  String? _failure;
  bool _microphoneOn = true;
  bool _cameraOn = true;
  bool _speakerOn = true;
  bool _disposed = false;

  @override
  CallMediaPhase get phase => _phase;

  @override
  String? get failure => _failure;

  @override
  bool get otherPersonPresent => _room.remoteParticipants.isNotEmpty;

  @override
  bool get otherPersonVideoOn => _otherVideoTrack != null;

  @override
  bool get microphoneOn => _microphoneOn;

  @override
  bool get cameraOn => _cameraOn;

  @override
  bool get speakerOn => _speakerOn;

  @override
  Future<void> join({
    required Uri serverUrl,
    required String token,
    bool withCamera = true,
  }) async {
    // A voice call starts with no camera at all. The button on the screen can
    // still turn it on later, which is what makes this a starting state rather
    // than a restriction.
    _cameraOn = withCamera;

    _set(CallMediaPhase.connecting, failure: null);
    _room.addListener(_onRoomChanged);

    try {
      await _room.connect(serverUrl.toString(), token);
    } catch (error) {
      _room.removeListener(_onRoomChanged);
      _set(
        CallMediaPhase.failed,
        failure:
            'Could not connect the call. Check your connection and try again.',
      );
      return;
    }

    // THE CAMERA AND MICROPHONE ARE ASKED FOR HERE, by turning each one on.
    //
    // The media plugin asks the phone at exactly this point, which is why the
    // app carries no separate permission package: one library asking is one
    // place for it to go wrong, and the request lands while the user is
    // looking at a call rather than at launch, where it would be refused and
    // remembered as refused.
    //
    // The microphone first, because a call nobody can hear is not a call.
    try {
      await _room.localParticipant?.setMicrophoneEnabled(_microphoneOn);
    } catch (error) {
      await _room.disconnect();
      _room.removeListener(_onRoomChanged);
      _set(
        CallMediaPhase.permissionRefused,
        failure:
            'Kinvo needs the microphone to call. You can turn it on in your '
            'phone settings.',
      );
      return;
    }

    // A refused camera is survivable: the call carries on with sound only, and
    // the screen says why there is no picture rather than showing a black
    // square that reads as a fault in the app.
    String? cameraFailure;

    try {
      // Skipped entirely for a voice call: never opened rather than opened
      // and muted.
      if (_cameraOn) {
        await _room.localParticipant?.setCameraEnabled(true);
      }
    } catch (error) {
      _cameraOn = false;
      cameraFailure =
          'Your camera is off because Kinvo was not allowed to use it.';
    }

    await lk.AudioManager.instance.setSpeakerOutputPreferred(_speakerOn);

    _set(CallMediaPhase.connected, failure: cameraFailure);
  }

  @override
  Future<void> leave() async {
    if (_phase == CallMediaPhase.closed) return;
    _room.removeListener(_onRoomChanged);

    try {
      await _room.disconnect();
    } catch (_) {
      // Leaving must never fail loudly: the call is over either way, and the
      // server has already been told.
    }

    _set(CallMediaPhase.closed);
  }

  @override
  Future<void> setMicrophone({required bool on}) async {
    _microphoneOn = on;
    _notify();
    await _room.localParticipant?.setMicrophoneEnabled(on);
  }

  @override
  Future<void> setCamera({required bool on}) async {
    _cameraOn = on;
    _notify();
    await _room.localParticipant?.setCameraEnabled(on);
  }

  @override
  Future<void> setSpeaker({required bool on}) async {
    _speakerOn = on;
    _notify();
    await lk.AudioManager.instance.setSpeakerOutputPreferred(on);
  }

  @override
  Future<void> flipCamera() async {
    final track = _selfVideoTrack;
    if (track == null) return;

    // The track carries the options it was started with, so which way it is
    // pointing is read from there rather than tracked separately — two copies
    // of that would disagree the first time a track restarts.
    final options = track.currentOptions;
    final facingFront =
        options is! lk.CameraCaptureOptions ||
        options.cameraPosition == lk.CameraPosition.front;

    await track.setCameraPosition(
      facingFront ? lk.CameraPosition.back : lk.CameraPosition.front,
    );
    _notify();
  }

  @override
  Widget? buildSelfView() {
    final track = _selfVideoTrack;
    if (track == null || !_cameraOn) return null;
    return lk.VideoTrackRenderer(track, fit: lk.VideoViewFit.cover);
  }

  @override
  Widget? buildOtherView() {
    final track = _otherVideoTrack;
    if (track == null) return null;
    return lk.VideoTrackRenderer(track, fit: lk.VideoViewFit.cover);
  }

  lk.LocalVideoTrack? get _selfVideoTrack {
    for (final publication
        in _room.localParticipant?.videoTrackPublications ??
            const <lk.LocalTrackPublication<lk.LocalVideoTrack>>[]) {
      final track = publication.track;
      // A muted publication keeps its track; rendering it shows a frozen
      // frame, which reads as a broken call rather than a camera turned off.
      if (track != null && !publication.muted) return track;
    }
    return null;
  }

  lk.VideoTrack? get _otherVideoTrack {
    for (final participant in _room.remoteParticipants.values) {
      for (final publication in participant.videoTrackPublications) {
        final track = publication.track;
        if (track != null && publication.subscribed && !publication.muted) {
          return track;
        }
      }
    }
    return null;
  }

  /// LiveKit raises a change for every event: someone joining, a track
  /// arriving, a camera muted. The screen reads what it needs on each one,
  /// which is simpler and less likely to miss a case than subscribing to a
  /// dozen event types.
  void _onRoomChanged() => _notify();

  void _set(CallMediaPhase phase, {String? failure}) {
    _phase = phase;
    _failure = failure;
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _room.removeListener(_onRoomChanged);
    // Fire and forget: dispose cannot await, and an undisposed room holds the
    // camera open. Errors are swallowed for the reason given in `leave`.
    unawaited(
      _room.disconnect().catchError((_) {}).whenComplete(_room.dispose),
    );
    super.dispose();
  }
}
