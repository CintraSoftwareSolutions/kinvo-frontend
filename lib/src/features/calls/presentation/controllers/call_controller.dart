import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/demo/demo_mode.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/ringtone/ringtone.dart';
import '../../../profile/domain/user_summary.dart';
import '../../../chat/data/live_updates.dart';
import '../../../chat/domain/live_update.dart';
import '../../data/calls_repository.dart';
import '../../domain/call.dart';
import '../../media/call_media.dart';
import '../../media/livekit_call_media.dart';
import '../call_notifications.dart';
import 'call_ringtone_controller.dart';

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

  /// Calls this app has already answered, or already ended, itself.
  ///
  /// The phone's own call screen and this app both report the same things:
  /// answering on the lock screen of a phone that was awake raises an event
  /// AND is remembered by the platform for a phone that was not, and closing
  /// that screen raises the ending it was told about. Without this, a call
  /// would be answered twice — and the server, rightly, refuses the second.
  final Set<String> _answered = {};
  final Set<String> _ended = {};

  /// How many of those to keep. A phone can only be in one call at a time, so
  /// a handful of recent ids covers every echo there can be, and an app left
  /// open for weeks does not collect them for ever.
  static const _rememberedCalls = 8;

  @override
  ActiveCall? build() {
    _updates = ref.watch(liveUpdatesProvider).stream.listen(_onUpdate);

    // Held now, not read later: a provider cannot be read while the container
    // is being disposed, and that is exactly when a phone left ringing needs
    // to be told to stop.
    final ringtones = ref.read(ringtonesProvider);

    ref.onDispose(() {
      _ringTimer?.cancel();
      unawaited(_updates?.cancel());
      // The media object owns the camera, so it is closed here even if the
      // screen went away without hanging up.
      _media?.dispose();
      _media = null;
      unawaited(ringtones.stop());
    });

    return null;
  }

  CallsRepository get _repository => ref.read(callsRepositoryProvider);

  CallRingtoneController get _ringtone =>
      ref.read(callRingtoneProvider.notifier);

  CallNotifications get _notifications => ref.read(callNotificationsProvider);

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
    unawaited(_ringtone.stopRinging());

    // Answering twice is the server's 409, and there is nothing to tell the
    // user about a call that is already theirs.
    if (!_remember(_answered, current.call.id)) return;

    try {
      final answered = await _repository.answer(current.call.id);
      state = current.copyWith(call: answered, clearFailure: true);
      // The phone may still be showing its own incoming call — answered in
      // the app while the lock screen was up. It becomes an ongoing call
      // rather than one still asking to be answered.
      unawaited(_notifications.markConnected(answered.id));
      unawaited(_connectMedia(answered));
    } on ApiException catch (error) {
      // Answering a call that stopped ringing, most often because the other
      // person gave up. Saying so is better than a screen that does nothing.
      state = current.copyWith(failure: _messageFor(error));
      await _close();
    }
  }

  /// Answers a call the person accepted from the lock screen.
  ///
  /// Nothing may be known about this call: the app may have been launched by
  /// the notification itself, with no socket, no state and no ringing screen.
  /// So it answers by id and builds the state from what the server gives back,
  /// rather than from anything already held.
  Future<void> answerFromNotification(String callId) async {
    await _ringtone.stopRinging();
    _ringTimer?.cancel();

    // Already the live call on this device: the ordinary path handles it, and
    // answering twice would be a second request for the same thing.
    if (state?.call.id == callId) {
      await answer();
      return;
    }

    if (!_remember(_answered, callId)) return;

    try {
      _begin(await _repository.answer(callId));
    } on ApiException {
      // The server will not let it be answered. Most often that is because it
      // already has been — from the lock screen of a phone that then started
      // this app, so the answer reached the server before there was anything
      // here to know about it. Joining a call that is already live is a
      // matter of asking for a token, not answering again.
      if (!await _joinAnswered(callId)) {
        // Genuinely over: answered on another phone, declined, or rung out.
        await _notifications.hide(callId);
      }
    }
  }

  /// Refuses a call the person declined from the lock screen.
  Future<void> declineFromNotification(String callId) async {
    await _ringtone.stopRinging();
    _remember(_ended, callId);
    await _declineQuietly(callId);
    await _notifications.hide(callId);

    if (state?.call.id == callId) await _close();
  }

  /// Hangs up a call ended from the lock screen's own controls.
  ///
  /// Closing that screen is itself an ending, and this app closes it whenever
  /// a call finishes — so an ending for a call this app has already finished
  /// with is its own echo, not something to tell the server about again.
  Future<void> endFromNotification(String callId) async {
    if (!_remember(_ended, callId)) return;

    if (state?.call.id == callId) {
      await hangUp();
      return;
    }

    try {
      await _repository.end(callId);
    } on ApiException {
      // Already over.
    }
  }

  /// Refuses a call that is ringing on this device.
  Future<void> decline() async {
    final current = state;
    if (current == null) return;

    _ringTimer?.cancel();
    unawaited(_ringtone.stopRinging());
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

    // Only for a call coming IN. The caller hears the other phone through the
    // call itself; ringing here would be this phone ringing at the person who
    // dialled.
    unawaited(_ringtone.startRinging());
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

  /// Puts a call this device has just joined on screen, from nothing.
  ///
  /// Used where there is no ringing state to build on: the app may have been
  /// started by the notification itself, so everything shown comes from what
  /// the server just gave back.
  void _begin(Call call) {
    _media = _mediaFor(call);
    state = ActiveCall(call: call, media: _media);
    // The phone is still showing its own incoming call — this app is only
    // running because somebody answered it.
    unawaited(_notifications.markConnected(call.id));
    unawaited(_connectMedia(call));
  }

  /// Joins a call the server already considers live, without answering it a
  /// second time. Returns whether there was one to join.
  ///
  /// Asking for a token is the whole difference: answering is the moment a
  /// ringing call becomes a live one, and that moment has passed.
  Future<bool> _joinAnswered(String callId) async {
    final Call call;
    try {
      call = await _repository.refreshToken(callId);
    } on ApiException {
      return false;
    }

    // A call this device started is not one to answer, and a call that is
    // over is not one to show.
    if (!call.status.isLive || call.isInitiator) return false;

    _begin(call);
    return true;
  }

  /// Remembers [callId], and returns false when it was already known.
  static bool _remember(Set<String> into, String callId) {
    if (!into.add(callId)) return false;
    if (into.length > _rememberedCalls) into.remove(into.first);
    return true;
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
    // The lock screen may still be showing this call on a phone that was
    // closed when it arrived. It goes with everything else — and closing it
    // is itself an ending, which comes back as an event this call has already
    // been through.
    if (state?.call.id case final callId?) {
      _remember(_ended, callId);
      unawaited(_notifications.hide(callId));
    }

    // Whatever ended it — the other side, a safety action, the ring timer —
    // the phone stops ringing here, once.
    unawaited(_ringtone.stopRinging());

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
