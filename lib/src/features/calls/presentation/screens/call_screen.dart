import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/widgets/person_photo.dart';
import '../../domain/call.dart';
import '../../media/call_media.dart';
import '../call_window.dart';
import '../controllers/call_controller.dart';
import '../widgets/call_safety_sheet.dart';

/// The call, from the first ring to the last frame.
///
/// One screen for every stage on purpose: ringing, connected and ended are the
/// same call, and pushing a second screen when it is answered would leave the
/// first one behind for the back button to find.
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  Timer? _tick;

  /// Held rather than read later: a provider cannot be read from dispose,
  /// and that is precisely when the lock screen must come back.
  late final CallWindow _window = ref.read(callWindowProvider);

  /// What the window was last asked for, so a screen that rebuilds every
  /// second asks the platform only when something has actually changed.
  bool? _awake;

  @override
  void initState() {
    super.initState();
    // Only to redraw the elapsed time; the call's own state comes from the
    // controller.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    // Over the lock screen from the first frame: this screen is often the
    // reason a sleeping phone woke up at all.
    unawaited(_window.set(showOverLockScreen: true, keepAwake: false));
  }

  @override
  void dispose() {
    _tick?.cancel();
    // After this the screen is gone, and the rest of Kinvo must be behind the
    // lock screen again.
    unawaited(_window.clear());
    super.dispose();
  }

  /// Keeps the screen lit while there is a picture to watch, and lets it
  /// behave normally on a voice call held to an ear.
  void _keepAwake({required bool awake}) {
    if (_awake == awake) return;
    _awake = awake;
    unawaited(_window.set(showOverLockScreen: true, keepAwake: awake));
  }

  @override
  Widget build(BuildContext context) {
    // The screen closes ITSELF when the call clears, rather than something
    // outside popping it: this widget is the route, so it is the only thing
    // that can be sure it is closing the right one.
    ref.listen<ActiveCall?>(callControllerProvider, (previous, next) {
      if (next != null || !mounted) return;
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
    });

    final call = ref.watch(callControllerProvider);

    if (call == null) {
      // The call ended and was dismissed. The shell closes this screen; this
      // is what it shows in the frame between the two.
      return const ColoredBox(color: Colors.black);
    }

    final media = call.media;
    _keepAwake(
      awake:
          call.call.kind == CallKind.video ||
          (media?.cameraOn ?? false) ||
          (media?.otherPersonVideoOn ?? false),
    );

    return PopScope(
      // Backing out of a call must not leave it running with the camera on.
      // Hanging up is what the user means by pressing back here.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(ref.read(callControllerProvider.notifier).hangUp());
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: media == null
            ? _CallBody(call: call, media: null)
            : ListenableBuilder(
                listenable: media,
                builder: (context, _) => _CallBody(call: call, media: media),
              ),
      ),
    );
  }
}

class _CallBody extends ConsumerWidget {
  const _CallBody({required this.call, required this.media});

  final ActiveCall call;
  final CallMedia? media;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(callControllerProvider.notifier);
    final other = call.otherUser;
    final otherView = media?.buildOtherView();

    return Stack(
      fit: StackFit.expand,
      children: [
        // Their picture when it is arriving, their photo until then. A black
        // rectangle while a call connects reads as a broken app.
        if (otherView != null)
          otherView
        else
          PersonPhoto(
            url: other.photoUrl,
            name: other.displayName,
            color: AppColors.purple,
            initialSize: 120,
          ),
        const _Scrim(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(call: call, media: media),
                const Spacer(),
                if (_note(call, media) case final note?) _Note(text: note),
                const SizedBox(height: 14),
                _Controls(call: call, media: media, controller: controller),
              ],
            ),
          ),
        ),
        if (media?.buildSelfView() case final selfView?)
          Positioned(
            right: 16,
            top: MediaQuery.paddingOf(context).top + 96,
            child: _SelfPreview(child: selfView),
          ),
      ],
    );
  }

  /// What the screen says under the picture, or null when there is nothing
  /// worth saying. Media problems come first: they are the reason someone
  /// cannot see or hear anything.
  static String? _note(ActiveCall call, CallMedia? media) {
    if (call.failure case final failure?) return failure;
    if (media?.failure case final failure?) return failure;

    return switch (media?.phase) {
      CallMediaPhase.connecting => 'Connecting…',
      CallMediaPhase.failed => 'The picture and sound could not connect.',
      _ when media == null && call.isActive =>
        'This call has no picture or sound: no video service is set up on '
            'this server yet.',
      _ when call.isActive && media?.otherPersonPresent == false =>
        'Waiting for ${call.otherUser.displayName} to join…',
      _ => null,
    };
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.call, required this.media});

  final ActiveCall call;
  final CallMedia? media;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Both pills shrink rather than overflow: two long labels side by
        // side ran off the edge of a narrow phone.
        Row(
          children: [
            Flexible(
              child: _Pill(
                text: call.call.kind == CallKind.audio
                    ? 'Voice call'
                    : 'Video call',
              ),
            ),
            const SizedBox(width: 8),
            const Spacer(),
            Flexible(child: _Pill(text: _status(call))),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          call.otherUser.displayName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  static String _status(ActiveCall call) {
    if (call.isActive) return _elapsed(call.call.answeredAt);

    return switch (call.call.status) {
      CallStatus.ringing when call.call.isInitiator => 'Calling…',
      // The pill beside this one already says which kind of call it is.
      CallStatus.ringing => 'Incoming',
      CallStatus.declined => 'Declined',
      CallStatus.missed => 'No answer',
      CallStatus.ended => _ended(call.call.durationSeconds),
      _ => 'Call',
    };
  }

  static String _ended(int? seconds) {
    if (seconds == null || seconds <= 0) return 'Call ended';
    return 'Call ended · ${_clock(Duration(seconds: seconds))}';
  }

  static String _elapsed(DateTime? answeredAt) {
    if (answeredAt == null) return 'Connected';
    final elapsed = DateTime.now().toUtc().difference(answeredAt.toUtc());
    return _clock(elapsed.isNegative ? Duration.zero : elapsed);
  }

  static String _clock(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.call,
    required this.media,
    required this.controller,
  });

  final ActiveCall call;
  final CallMedia? media;
  final CallController controller;

  @override
  Widget build(BuildContext context) {
    if (call.call.status.isLive && call.isIncoming) {
      return Row(
        children: [
          _CallButton(
            icon: Icons.call_end_rounded,
            label: 'Decline',
            background: AppColors.danger,
            size: 64,
            onTap: call.ending ? null : () => unawaited(controller.decline()),
          ),
          _CallButton(
            icon: call.call.kind == CallKind.audio
                ? Icons.call_rounded
                : Icons.videocam_rounded,
            label: 'Answer',
            background: AppColors.success,
            size: 64,
            onTap: call.ending ? null : () => unawaited(controller.answer()),
          ),
        ],
      );
    }

    if (!call.call.status.isLive) {
      return Center(
        child: TextButton(
          onPressed: () => unawaited(controller.dismiss()),
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          child: const Text('Done'),
        ),
      );
    }

    final enabled = media != null && media!.phase == CallMediaPhase.connected;

    // With no media — a server with no video service, or a call still
    // connecting — the controls show what this call would be rather than what
    // it is, because nothing is on or off yet. They are greyed out, and none
    // of them is lit: an unusable button that looks switched on is a lie.
    final video = call.call.kind == CallKind.video;
    final microphoneOn = media?.microphoneOn ?? true;
    final speakerOn = media?.speakerOn ?? video;
    final cameraOn = media?.cameraOn ?? video;

    return Row(
      children: [
        // The three toggles keep their names and show their state, the way
        // every phone's call screen does: the icon says which way it is, and
        // the button is filled while it is doing the notable thing. A label
        // that changed under a thumb would be read after it was pressed.
        _CallButton(
          icon: microphoneOn ? Icons.mic_rounded : Icons.mic_off_rounded,
          label: 'Mute',
          active: enabled && !microphoneOn,
          onTap: enabled
              ? () => unawaited(media!.setMicrophone(on: !microphoneOn))
              : null,
        ),
        _CallButton(
          icon: speakerOn ? Icons.volume_up_rounded : Icons.hearing_rounded,
          label: 'Speaker',
          active: enabled && speakerOn,
          onTap: enabled
              ? () => unawaited(media!.setSpeaker(on: !speakerOn))
              : null,
        ),
        _CallButton(
          icon: cameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
          label: 'Video',
          active: enabled && !cameraOn,
          onTap: enabled
              ? () => unawaited(media!.setCamera(on: !cameraOn))
              : null,
        ),
        _CallButton(
          icon: Icons.shield_rounded,
          label: 'Safety',
          onTap: () => unawaited(showCallSafetySheet(context)),
        ),
        _CallButton(
          icon: Icons.call_end_rounded,
          label: 'End',
          background: AppColors.danger,
          size: 60,
          onTap: call.ending ? null : () => unawaited(controller.hangUp()),
        ),
      ],
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.background,
    this.size = 52,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? background;
  final double size;

  /// Whether the thing this button controls is in its notable state — muted,
  /// on the loudspeaker, camera off. Drawn filled, as every phone draws a
  /// call control that is doing something.
  final bool active;

  @override
  Widget build(BuildContext context) {
    // The label is part of the button, not a caption beside it: a 52-pixel
    // circle is a small target for a thumb during a call, and someone aiming
    // for "End" hits the word as often as the icon.
    final foreground = active ? Colors.black87 : Colors.white;

    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        // Screen readers hear the state as well as the name, which is the
        // whole difference between "Mute" and "Mute, on".
        toggled: background == null ? active : null,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Opacity(
            opacity: onTap == null ? 0.5 : 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color:
                        background ?? (active ? Colors.white : Colors.white24),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: background == null ? foreground : Colors.white,
                    size: size * 0.44,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          height: 1.4,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.55),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.8),
          ],
          stops: const [0, 0.4, 1],
        ),
      ),
    );
  }
}

class _SelfPreview extends StatelessWidget {
  const _SelfPreview({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 128,
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
