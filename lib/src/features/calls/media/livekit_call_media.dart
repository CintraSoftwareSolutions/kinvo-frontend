import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:permission_handler/permission_handler.dart';

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
  Future<void> join({required Uri serverUrl, required String token}) async {
    _set(CallMediaPhase.connecting, failure: null);

    // Asked for HERE rather than at launch: an app that wants the camera
    // before showing anything gets refused, and Android remembers a refusal.
    final permissions = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    final micDenied = permissions[Permission.microphone]?.isGranted != true;
    final cameraDenied = permissions[Permission.camera]?.isGranted != true;

    if (micDenied) {
      // Without a microphone there is no call worth joining. The camera alone
      // being refused is survivable, and handled below.
      _set(
        CallMediaPhase.permissionRefused,
        failure:
            'Kinvo needs the microphone to call. You can turn it on in your '
            'phone settings.',
      );
      return;
    }

    if (cameraDenied) {
      _cameraOn = false;
    }

    _room.addListener(_onRoomChanged);

    try {
      await _room.connect(serverUrl.toString(), token);
      await _room.localParticipant?.setMicrophoneEnabled(_microphoneOn);
      if (_cameraOn) {
        await _room.localParticipant?.setCameraEnabled(true);
      }
      await lk.AudioManager.instance.setSpeakerOutputPreferred(_speakerOn);
    } catch (error) {
      _room.removeListener(_onRoomChanged);
      _set(
        CallMediaPhase.failed,
        failure: cameraDenied
            ? 'Could not connect the call.'
            : 'Could not connect the call. Check your connection and try again.',
      );
      return;
    }

    _set(
      CallMediaPhase.connected,
      // Connected, but worth saying why they cannot be seen: otherwise a black
      // square reads as a fault in the app.
      failure: cameraDenied
          ? 'Your camera is off because Kinvo was not allowed to use it.'
          : null,
    );
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
