import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/server_config_providers.dart';
import '../../../../core/entitlements/paywall.dart';
import '../../../../core/network/api_error_code.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/modes_repository.dart';
import '../../domain/mode_choice.dart';
import '../../domain/user_modes.dart';

/// The signed-in user's modes, as `GET /modes` has them: which are on, which
/// is the main one, and how many the plan allows.
///
/// The one copy every screen reads — Discover, its mode switcher, Your modes,
/// Profile, Settings — so switching a mode on anywhere shows everywhere at
/// once. Every change is read back from the server afterwards, because the
/// server may move the main mode as a result of it.
final userModesProvider =
    AsyncNotifierProvider.autoDispose<UserModesController, UserModes>(
      UserModesController.new,
    );

/// Every mode, with where the account stands with each: for the mode
/// switcher on Discover and the Your modes screen.
final modeChoicesProvider = Provider.autoDispose<AsyncValue<List<ModeChoice>>>((
  ref,
) {
  final modes = ref.watch(userModesProvider);
  final config = ref.watch(serverConfigProvider);
  if (modes.hasError && !modes.hasValue) {
    return AsyncError(modes.error!, modes.stackTrace ?? StackTrace.current);
  }
  if (config.hasError && !config.hasValue) {
    return AsyncError(config.error!, config.stackTrace ?? StackTrace.current);
  }
  final loadedModes = modes.value;
  final loadedConfig = config.value;
  if (loadedModes == null || loadedConfig == null) return const AsyncLoading();
  return AsyncData(modeChoicesFrom(loadedModes, loadedConfig));
});

/// How a change to the user's modes turned out.
@immutable
sealed class ModeChange {
  const ModeChange();
}

/// Done, and the server's answer is now in [userModesProvider].
final class ModeChanged extends ModeChange {
  const ModeChanged();
}

/// The plan's limit on modes at once is reached. [paywall] says so and
/// offers the upgrade.
final class ModeNeedsUpgrade extends ModeChange {
  const ModeNeedsUpgrade(this.paywall);

  final Paywall paywall;
}

/// The mode is only for people who have verified their identity.
final class ModeNeedsVerification extends ModeChange {
  const ModeNeedsVerification(this.message);

  final String message;
}

/// Refused here, without asking the server: the last mode that's on stays
/// on, because Discover and matching need one.
final class LastModeKept extends ModeChange {
  const LastModeKept();
}

/// It didn't work. [message] says why, in words a person can read.
final class ModeChangeFailed extends ModeChange {
  const ModeChangeFailed(this.message);

  final String message;
}

class UserModesController extends AsyncNotifier<UserModes> {
  ModesRepository get _repository => ref.read(modesRepositoryProvider);

  /// A change is on its way, so a second one waits its turn rather than
  /// racing it: two switches at once could each pass the plan's limit.
  bool _changing = false;

  @override
  Future<UserModes> build() {
    return ref.watch(modesRepositoryProvider).fetch();
  }

  /// Reads the modes again, as they are on the server now.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Switches [mode] on. The server decides whether it may be: the plan's
  /// limit on modes at once, and a verified identity for some modes.
  Future<ModeChange> turnOn(String mode) {
    return _change(() async {
      await _repository.setEnabled(mode, enabled: true);
      return null;
    });
  }

  /// Switches [mode] off. Switching off the main mode makes another one the
  /// main mode, as the server decides.
  Future<ModeChange> turnOff(String mode) {
    final enabled = state.value?.enabledModes ?? const <String>[];
    if (enabled.length <= 1 && enabled.contains(mode)) {
      return Future.value(const LastModeKept());
    }
    return _change(() async {
      await _repository.setEnabled(mode, enabled: false);
      return null;
    });
  }

  /// Makes [mode], which must be on, the main mode: the one the app opens in.
  Future<ModeChange> makeMain(String mode) {
    return _change(() => _repository.makePrimary(mode));
  }

  /// Runs [action], then keeps the server's answer: the one [action]
  /// returns, or else one read afresh.
  Future<ModeChange> _change(Future<UserModes?> Function() action) async {
    if (_changing) {
      return const ModeChangeFailed('One moment — the last change is saving.');
    }
    _changing = true;
    try {
      final answer = await action() ?? await _repository.fetch();
      if (ref.mounted) state = AsyncData(answer);
      return const ModeChanged();
    } on ApiException catch (error) {
      // Part of it may have happened before it failed, so the server's
      // answer is read again rather than guessed.
      unawaited(_reloadQuietly());
      if (Paywall.fromError(error) case final paywall?) {
        return ModeNeedsUpgrade(paywall);
      }
      if (error case ApiErrorException(
        code: ApiErrorCode.forbidden,
        :final details,
        :final message,
      ) when details?['reason'] == 'verification_required') {
        return ModeNeedsVerification(message);
      }
      return ModeChangeFailed(error.message);
    } finally {
      _changing = false;
    }
  }

  Future<void> _reloadQuietly() async {
    try {
      final fresh = await _repository.fetch();
      if (ref.mounted) state = AsyncData(fresh);
    } on ApiException catch (error, stackTrace) {
      // What's on screen stays until the next read.
      developer.log(
        'Could not re-read modes after a failed change.',
        name: 'kinvo.modes',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
