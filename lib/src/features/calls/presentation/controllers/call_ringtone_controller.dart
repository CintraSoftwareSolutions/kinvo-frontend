import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ringtone/ringtone.dart';
import '../../../../core/storage/storage_providers.dart';

/// Which ringtone a call rings with on this phone.
@immutable
final class CallRingtone {
  const CallRingtone({required this.title, this.uri, this.canChoose = false});

  /// What Settings shows. The phone's own default until something is chosen.
  final String title;

  /// The chosen sound, or null for the phone's default ringtone.
  final String? uri;

  /// False on a phone with no ringtone chooser — every iPhone. Settings then
  /// says so rather than offering a button that cannot work.
  final bool canChoose;

  bool get isDefault => uri == null;
}

/// Remembers the chosen ringtone, and is what the call screen rings with.
///
/// The choice is stored as the phone's own address for the sound. That address
/// can stop working — a ringtone on a removed SD card, or one belonging to an
/// app that has been uninstalled — so the name is read back from the phone
/// each time rather than stored beside it. A name that no longer resolves
/// falls back to the default, which is what the call would ring with anyway.
final class CallRingtoneController extends AsyncNotifier<CallRingtone> {
  static const storageKey = 'call_ringtone_uri';

  Ringtones get _ringtones => ref.read(ringtonesProvider);

  @override
  Future<CallRingtone> build() async {
    final ringtones = _ringtones;
    if (!ringtones.canChoose) {
      return const CallRingtone(title: 'Default ringtone');
    }

    final store = ref.read(preferencesKeyValueStoreProvider);
    final saved = await store.read(storageKey);

    if (saved == null || saved.isEmpty) {
      return CallRingtone(
        title: await ringtones.defaultTitle() ?? 'Default ringtone',
        canChoose: true,
      );
    }

    final title = await ringtones.titleOf(saved);

    if (title == null) {
      // The sound has gone. Forget it rather than leaving a setting that
      // silently does nothing.
      await store.delete(storageKey);
      return CallRingtone(
        title: await ringtones.defaultTitle() ?? 'Default ringtone',
        canChoose: true,
      );
    }

    return CallRingtone(title: title, uri: saved, canChoose: true);
  }

  /// Opens the phone's ringtone chooser. Backing out keeps what was there.
  Future<void> choose() async {
    final current = state.value;
    final chosen = await _ringtones.choose(current: current?.uri);
    if (chosen == null) return;

    await ref
        .read(preferencesKeyValueStoreProvider)
        .write(storageKey, chosen.uri);

    state = AsyncData(
      CallRingtone(title: chosen.title, uri: chosen.uri, canChoose: true),
    );
  }

  /// Back to the phone's own ringtone.
  Future<void> useDefault() async {
    await ref.read(preferencesKeyValueStoreProvider).delete(storageKey);

    state = AsyncData(
      CallRingtone(
        title: await _ringtones.defaultTitle() ?? 'Default ringtone',
        canChoose: _ringtones.canChoose,
      ),
    );
  }

  /// Starts ringing for a call that is coming in. Never for one going out: the
  /// caller hears the other phone through the call itself, and a second sound
  /// on this side would be this phone ringing at the person who dialled.
  Future<void> startRinging() async {
    await _ringtones.play(uri: state.value?.uri);
  }

  Future<void> stopRinging() => _ringtones.stop();
}

final callRingtoneProvider =
    AsyncNotifierProvider<CallRingtoneController, CallRingtone>(
      CallRingtoneController.new,
    );
