import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A ringtone the user chose, as the phone describes it.
@immutable
final class ChosenRingtone {
  const ChosenRingtone({required this.uri, required this.title});

  /// What the phone calls this sound, for showing in Settings.
  final String title;

  /// The phone's own address for it. Opaque: it is stored and handed back,
  /// never parsed.
  final String uri;
}

/// The phone's ringtones: choosing one, and ringing with it.
///
/// Android only. iPhone plays only sounds bundled inside the app, so there is
/// no chooser to open there and [canChoose] answers false rather than throwing
/// — a missing feature is not an error.
abstract interface class Ringtones {
  bool get canChoose;

  /// Opens the phone's ringtone chooser, starting at [current]. Returns null
  /// when the user backs out, which means "keep what you had".
  Future<ChosenRingtone?> choose({String? current});

  /// What the phone calls [uri], or null if that sound has gone away — an SD
  /// card removed, an app uninstalled.
  Future<String?> titleOf(String uri);

  /// The name of the phone's own default ringtone, for the Settings row before
  /// anyone has chosen anything.
  Future<String?> defaultTitle();

  /// Rings, on a loop, until [stop]. Silent when the phone is: this plays on
  /// the ring stream, so the phone's own silent and vibrate modes decide what
  /// is heard, exactly as for a real call.
  Future<void> play({String? uri, bool vibrate = true});

  Future<void> stop();
}

/// [Ringtones] over the platform channel in `RingtoneBridge.kt`.
final class PlatformRingtones implements Ringtones {
  const PlatformRingtones();

  static const _channel = MethodChannel('kinvo/ringtone');

  @override
  bool get canChoose => defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<ChosenRingtone?> choose({String? current}) async {
    if (!canChoose) return null;

    final chosen = await _invoke<Map<Object?, Object?>>('pick', {
      'current': current,
    });

    if (chosen == null) return null;

    final uri = chosen['uri'];
    if (uri is! String || uri.isEmpty) return null;

    final title = chosen['title'];
    return ChosenRingtone(
      uri: uri,
      title: title is String && title.isNotEmpty ? title : 'Chosen ringtone',
    );
  }

  @override
  Future<String?> titleOf(String uri) {
    return _invoke<String>('titleOf', {'uri': uri});
  }

  @override
  Future<String?> defaultTitle() => _invoke<String>('defaultTitle');

  @override
  Future<void> play({String? uri, bool vibrate = true}) async {
    await _invoke<void>('play', {'uri': uri, 'vibrate': vibrate});
  }

  @override
  Future<void> stop() async {
    await _invoke<void>('stop');
  }

  /// Every call is best-effort. A phone that cannot ring must not stop a call
  /// from arriving: the screen still appears, silently.
  Future<T?> _invoke<T>(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    if (!canChoose) return null;

    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      debugPrint('ringtone ${error.code}: ${error.message}');
      return null;
    } on MissingPluginException {
      // A test, or a platform without the bridge.
      return null;
    }
  }
}

/// Does nothing, for tests and for platforms with no ringtone chooser.
final class SilentRingtones implements Ringtones {
  const SilentRingtones();

  @override
  bool get canChoose => false;

  @override
  Future<ChosenRingtone?> choose({String? current}) async => null;

  @override
  Future<String?> titleOf(String uri) async => null;

  @override
  Future<String?> defaultTitle() async => null;

  @override
  Future<void> play({String? uri, bool vibrate = true}) async {}

  @override
  Future<void> stop() async {}
}

final ringtonesProvider = Provider<Ringtones>((ref) {
  return const PlatformRingtones();
});
