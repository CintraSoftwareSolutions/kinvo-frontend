import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/demo/demo_mode.dart';
import '../../../../core/network/api_exception.dart';
import '../../../profile/domain/user_summary.dart';
import '../../../chat/data/live_updates.dart';
import '../../../chat/domain/live_update.dart';
import '../../data/calls_repository.dart';
import '../../domain/call.dart';
import '../../media/call_media.dart';
import '../../media/livekit_call_media.dart';

/// How long a call rings before it counts as missed.
///
/// The server decides this — it answers `missed` for a call still marked
/// ringing after a minute — and the app matches it so the two never disagree
/// about whether a call is still worth answering. Kept a little longer here so
/// the server's answer arrives first and the app shows what the server says.
const ringingTimeout = Duration(seconds: 65);

/// A call in progress on this device, from the first ring to the last frame.
@immutable
final class ActiveCall {
  const ActiveCall({
    required this.call,
    required this.media,
    this.ending = false,
    this.failure,
  });

  final Call call;

  /// Null when this call carries no picture or sound: the demo, or a server
  /// with no video service configured. Everything else still works.
  final CallMedia? media;

  /// True from the moment the user hangs up until the screen closes, so the
  /// button cannot be pressed twice.
  final bool ending;

  /// Something that went wrong with the call itself, in words. Media problems
  /// live on [media] instead.
  final String? failure;

  bool get isRinging => call.status == CallStatus.ringing;
  bool get isActive => call.status == CallStatus.active;

  /// Whether the other person still has to pick up on this device.
  bool get isIncoming => call.status == CallStatus.ringing && !call.isInitiator;

  UserSummary get otherUser => call.otherUser;

  ActiveCall copyWith({
    Call? call,
    CallMedia? media,
    bool? ending,
    String? failure,
    bool clearFailure = false,
  }) {
    return ActiveCall(
      call: call ?? this.call,
      media: media ?? this.media,
      ending: ending ?? this.ending,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

/// The one call this device is in, or null.
///
/// One at a time on purpose: the server refuses a second call on the same
/// match, and a person cannot be in two calls anyway. A call arriving while
/// another is live is declined for them rather than silently dropped.
final class CallController extends Notifier<ActiveCall?> {
  Timer? _ringTimer;
  StreamSubscription<LiveUpdate>? _updates;

  /// The same object the state carries, held here as well because the state
  /// cannot be read while the provider is being disposed — and that is exactly
  /// when the camera most needs releasing.
  CallMedia? _media;

  @override
  ActiveCall? build() {
    _updates = ref.watch(liveUpdatesProvider).stream.listen(_onUpdate);

    ref.onDispose(() {
      _ringTimer?.cancel();
      unawaited(_updates?.cancel());
      // The media object owns the camera, so it is closed here even if the
      // screen went away without hanging up.
      _media?.dispose();
      _media = null;
    });

    return null;
  }

  CallsRepository get _repository => ref.read(callsRepositoryProvider);

  /// Rings the other person in [matchId]. Returns the call, or null when the
  /// server refused; the reason is shown by whoever called this.
  Future<Call?> start(String matchId, {CallKind kind = CallKind.video}) async {
    if (state != null) return null;

    final call = await _repository.start(matchId, kind: kind);
    _media = _mediaFor(call);
    state = ActiveCall(call: call, media: _media);
    _startRingTimer();

    // The caller joins the room while it rings, so the picture is already
    // there the moment the other person answers rather than a second later.
    unawaited(_connectMedia(call));
    return call;
  }

  /// Picks up a call that is ringing on this device.
  Future<void> answer() async {
    final current = state;
    if (current == null || !current.isIncoming) return;

    _ringTimer?.cancel();

    try {
      final answered = await _repository.answer(current.call.id);
      state = current.copyWith(call: answered, clearFailure: true);
      unawaited(_connectMedia(answered));
    } on ApiException catch (error) {
      // Answering a call that stopped ringing, most often because the other
      // person gave up. Saying so is better than a screen that does nothing.
      state = current.copyWith(failure: _messageFor(error));
      await _close();
    }
  }

  /// Refuses a call that is ringing on this device.
  Future<void> decline() async {
    final current = state;
    if (current == null) return;

    _ringTimer?.cancel();
    state = current.copyWith(ending: true);

    try {
      await _repository.decline(current.call.id);
    } on ApiException {
      // It had already stopped ringing. Nothing to tell them: the call is
      // over either way, which is what they asked for.
    }

    await _close();
  }

  /// Hangs up. Safe to call twice — the server treats a second one as a no-op.
  Future<void> hangUp() async {
    final current = state;
    if (current == null || current.ending) return;

    _ringTimer?.cancel();
    state = current.copyWith(ending: true);

    try {
      await _repository.end(current.call.id);
    } on ApiException {
      // The call is over on this phone whatever the server says. Leaving the
      // screen up because a request failed would trap the user in a call.
    }

    await _close();
  }

  /// Records a safety action during the call. `end_and_report` ends the call,
  /// so the screen closes with it.
  Future<CallSafetyResult> recordSafetyAction(
    CallSafetyAction action, {
    String? note,
  }) async {
    final current = state;
    if (current == null) {
      throw StateError('There is no call to act on.');
    }

    final result = await _repository.recordSafetyAction(
      current.call.id,
      action,
      note: note,
    );

    if (result.callEnded) await _close();
    return result;
  }

  /// Closes the call screen after it has ended, without telling the server
  /// again. Used by the screen's "Done" button.
  Future<void> dismiss() => _close();

  /// The server's live events about this call. A call the user is not in is
  /// ignored: two calls at once cannot happen, and acting on a stale id would
  /// hang up the wrong one.
  void _onUpdate(LiveUpdate update) {
    switch (update) {
      case CallIncoming(:final callId) when state != null:
        // Already in a call. Declining is the honest answer — the other person
        // sees "declined" rather than ringing out for a minute.
        unawaited(_declineQuietly(callId));
      case CallIncoming():
        unawaited(_receive(update));
      case CallChanged(:final callId, :final status)
          when callId == state?.call.id:
        _applyStatus(status, update.durationSeconds);
      case _:
        break;
    }
  }

  /// Refuses a call the user cannot take, without surfacing a failure: they
  /// never asked for this and are busy on another call.
  Future<void> _declineQuietly(String callId) async {
    try {
      await _repository.decline(callId);
    } on ApiException {
      // It stopped ringing on its own.
    }
  }

  Future<void> _receive(CallIncoming update) async {
    // Everything but the person and the ids is filled in when it is answered:
    // the incoming event carries no token, because a call that is never
    // answered must never mint one.
    state = ActiveCall(
      call: Call(
        id: update.callId,
        matchId: update.matchId,
        mode: update.mode,
        kind: update.kind,
        status: CallStatus.ringing,
        isInitiator: false,
        otherUser: update.from,
        startedAt: null,
        answeredAt: null,
        endedAt: null,
        durationSeconds: null,
        createdAt: DateTime.now().toUtc(),
      ),
      media: null,
    );
    _startRingTimer();
  }

  void _applyStatus(CallStatus status, int? durationSeconds) {
    final current = state;
    if (current == null) return;

    switch (status) {
      case CallStatus.active:
        _ringTimer?.cancel();
        state = current.copyWith(
          call: current.call.copyWith(status: CallStatus.active),
        );
      case CallStatus.declined || CallStatus.ended || CallStatus.missed:
        _ringTimer?.cancel();
        state = current.copyWith(
          call: current.call.copyWith(
            status: status,
            durationSeconds: durationSeconds,
          ),
        );
        unawaited(_close(keepEnded: true));
      case CallStatus.ringing || CallStatus.unknown:
        break;
    }
  }

  /// Nobody answered. The server says `missed` at the same point, so this only
  /// makes the screen agree with it without waiting for a round trip.
  void _startRingTimer() {
    _ringTimer?.cancel();
    _ringTimer = Timer(ringingTimeout, () {
      final current = state;
      if (current == null || !current.isRinging) return;
      if (current.call.isInitiator) {
        unawaited(hangUp());
      } else {
        // The callee's phone simply stops ringing: the server has already
        // written the call off, so telling it again would only fail.
        unawaited(_close());
      }
    });
  }

  CallMedia? _mediaFor(Call call) {
    // No address means no video service configured — staging, or the demo. The
    // call itself still works, and the screen says why there is no picture.
    if (call.video?.isConnectable != true) return null;
    if (ref.read(demoSessionProvider)) return null;
    return LiveKitCallMedia();
  }

  Future<void> _connectMedia(Call call) async {
    final current = state;
    final video = call.video;
    if (current == null || video?.serverUrl == null) return;

    var media = _media;
    if (media == null) {
      media = _mediaFor(call);
      if (media == null) return;
      _media = media;
      state = current.copyWith(media: media);
    }

    await media.join(
      serverUrl: video!.serverUrl!,
      token: video.token,
      withCamera: call.kind.startsWithCamera,
    );
  }

  /// Ends the screen's life: closes the media and clears the call.
  ///
  /// [keepEnded] leaves the finished call on screen for a moment so the person
  /// sees why it stopped — "Declined", or how long it lasted — instead of
  /// being dropped back into the chat with no explanation.
  Future<void> _close({bool keepEnded = false}) async {
    final media = _media;
    if (media != null) {
      await media.leave();
    }

    if (keepEnded) {
      // The screen shows the ended state and calls `dismiss` itself.
      state = state?.copyWith(ending: true);
      return;
    }

    media?.dispose();
    _media = null;
    state = null;
  }

  static String _messageFor(ApiException error) {
    return switch (error) {
      ApiErrorException(:final message) => message,
      _ => 'Could not reach Kinvo. Check your connection.',
    };
  }
}

/// The call this device is in, or null. Watched by the call screen and by the
/// shell that opens it.
final callControllerProvider = NotifierProvider<CallController, ActiveCall?>(
  CallController.new,
);
