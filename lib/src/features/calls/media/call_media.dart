import 'package:flutter/widgets.dart';

/// How far the picture and sound have got.
///
/// Separate from the call's own status, which is the server's and is about
/// whether the two people are in a call at all. A call can be `active` while
/// the media is still connecting, or has failed — the screen says so instead
/// of pretending the call has dropped.
enum CallMediaPhase {
  /// Nothing has been asked for yet.
  idle,

  /// Asking for the camera and microphone, and joining the room.
  connecting,

  /// In the room. The other person may not have joined yet.
  connected,

  /// The camera or microphone was refused. The call can carry on without one.
  permissionRefused,

  /// The room could not be joined, or the connection was lost for good.
  failed,

  /// Left deliberately.
  closed,
}

/// Picture and sound for one call.
///
/// An interface so the call screen never imports a vendor's SDK, and so tests
/// can run the whole call without one. The one implementation
/// that does is [LiveKitCallMedia]; it is the only file that knows which
/// service is behind a call, matching the backend's provider interface.
abstract class CallMedia extends ChangeNotifier {
  CallMediaPhase get phase;

  /// Why joining failed, in words a person can read. Null unless [phase] is
  /// [CallMediaPhase.failed] or [CallMediaPhase.permissionRefused].
  String? get failure;

  /// Whether the other person is in the room and sending anything.
  bool get otherPersonPresent;

  /// Whether their camera is on. False means they are there but not seen.
  bool get otherPersonVideoOn;

  bool get microphoneOn;
  bool get cameraOn;
  bool get speakerOn;

  /// Joins the room. Asks for the camera and microphone first; a refusal
  /// leaves [phase] at [CallMediaPhase.permissionRefused] rather than throwing,
  /// because the call itself is still worth continuing.
  ///
  /// [withCamera] is false for a voice call. The camera is then never opened,
  /// not opened and muted: a phone that lights its camera indicator during a
  /// voice call has broken the promise the call was started on.
  Future<void> join({
    required Uri serverUrl,
    required String token,
    bool withCamera = true,
  });

  /// Leaves the room and releases the camera. Safe to call twice.
  Future<void> leave();

  Future<void> setMicrophone({required bool on});
  Future<void> setCamera({required bool on});

  /// Earpiece or loudspeaker. Ignored where the platform decides for itself.
  Future<void> setSpeaker({required bool on});

  /// Front camera to back and back again.
  Future<void> flipCamera();

  /// The user's own picture, or null when the camera is off or not running.
  Widget? buildSelfView();

  /// The other person's picture, or null when they have no camera on.
  Widget? buildOtherView();
}
