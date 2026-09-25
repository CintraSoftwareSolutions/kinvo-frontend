import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../../core/auth/session_status.dart';
import '../../../../core/theme/app_appearance.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/units/distance.dart';
import '../../data/settings_repository.dart';
import '../../domain/signed_in_device.dart';
import '../../domain/user_settings.dart';

/// The signed-in user's settings.
///
/// Kept for the whole session: the distance unit is read on every card, and
/// so is the text size. Starts again when the session changes.
final userSettingsProvider =
    AsyncNotifierProvider<UserSettingsController, UserSettings>(
      UserSettingsController.new,
    );

class UserSettingsController extends AsyncNotifier<UserSettings> {
  @override
  Future<UserSettings> build() async {
    final session = ref.watch(sessionStatusProvider);

    // Nobody is signed in: there are no settings to read, and asking for them
    // would be a request with no session behind it, made from the welcome
    // screen.
    if (session is! SignedIn) return UserSettings.defaults;

    return ref.watch(settingsRepositoryProvider).fetchSettings();
  }

  /// Changes the settings given. The change shows at once and is undone if
  /// the server refuses it, which throws an `ApiException`.
  Future<void> change({
    DistanceUnit? distanceUnit,
    bool? showDistance,
    bool? showLastActive,
    AppThemeChoice? theme,
    double? textScale,
    bool? reduceMotion,
    bool? highContrast,
    bool? incognito,
    bool? verifiedOnlyEverywhere,
    bool? pauseNewMatches,
  }) async {
    final before = state.value;
    if (before == null) return;
    state = AsyncData(
      before.copyWith(
        distanceUnit: distanceUnit,
        showDistance: showDistance,
        showLastActive: showLastActive,
        theme: theme,
        textScale: textScale,
        reduceMotion: reduceMotion,
        highContrast: highContrast,
        incognito: incognito,
        verifiedOnlyEverywhere: verifiedOnlyEverywhere,
        pauseNewMatches: pauseNewMatches,
      ),
    );
    try {
      final saved = await ref
          .read(settingsRepositoryProvider)
          .update(
            distanceUnit: distanceUnit,
            showDistance: showDistance,
            showLastActive: showLastActive,
            theme: theme,
            textScale: textScale,
            reduceMotion: reduceMotion,
            highContrast: highContrast,
            incognito: incognito,
            verifiedOnlyEverywhere: verifiedOnlyEverywhere,
            pauseNewMatches: pauseNewMatches,
          );
      if (ref.mounted) state = AsyncData(saved);
    } on Object {
      if (ref.mounted) state = AsyncData(before);
      rethrow;
    }
  }

  /// Hides the user from Discover for [duration], or until they come back
  /// when it's `null`. Throws an `ApiException` when the server refuses.
  Future<void> takeBreak({Duration? duration}) async {
    final until = duration == null
        ? null
        : ref.read(clockProvider)().add(duration);
    final saved = await ref
        .read(settingsRepositoryProvider)
        .takeBreak(until: until);
    if (ref.mounted) state = AsyncData(saved);
  }

  /// Shows the user in Discover again. Throws an `ApiException` when the
  /// server refuses.
  Future<void> endBreak() async {
    final saved = await ref.read(settingsRepositoryProvider).endBreak();
    if (ref.mounted) state = AsyncData(saved);
  }
}

/// How the app should look and move, for the whole app to read.
///
/// Defaults until the settings arrive and when they can't be read, so a
/// server that is slow or unreachable never leaves someone stuck with text
/// they cannot see.
final appearanceProvider = Provider<AppAppearance>((ref) {
  final settings = ref.watch(
    userSettingsProvider.select((settings) => settings.value),
  );

  return AppAppearance(
    theme: settings?.theme ?? AppThemeChoice.system,
    textScale: settings?.textScale ?? 1,
    reduceMotion: settings?.reduceMotion ?? false,
    highContrast: settings?.highContrast ?? false,
  );
});

/// How distances are shown. Miles until the settings arrive, and when they
/// can't be read.
final distanceUnitProvider = Provider<DistanceUnit>((ref) {
  return ref.watch(
        userSettingsProvider.select((settings) => settings.value?.distanceUnit),
      ) ??
      DistanceUnit.miles;
});

/// The phones and tablets signed in to the account, read afresh each time the
/// list is shown.
final signedInDevicesProvider =
    AsyncNotifierProvider.autoDispose<
      SignedInDevicesController,
      List<SignedInDevice>
    >(SignedInDevicesController.new);

class SignedInDevicesController extends AsyncNotifier<List<SignedInDevice>> {
  @override
  Future<List<SignedInDevice>> build() {
    return ref.watch(devicesRepositoryProvider).fetchDevices();
  }

  /// Signs the device [deviceId] out and takes it off the list. Throws an
  /// `ApiException` when the server refuses; the list then shows what the
  /// server has.
  Future<void> signOut(String deviceId) async {
    final devices = ref.read(devicesRepositoryProvider);
    try {
      await devices.signOut(deviceId);
      final current = state.value;
      if (ref.mounted && current != null) {
        state = AsyncData([
          for (final device in current)
            if (device.id != deviceId) device,
        ]);
      }
    } on Object {
      if (ref.mounted) ref.invalidateSelf();
      rethrow;
    }
  }

  /// Signs out every device but this one. Returns how many were signed out.
  /// Throws an `ApiException` when the server refuses.
  Future<int> signOutOthers() async {
    final count = await ref.read(devicesRepositoryProvider).signOutOthers();
    final current = state.value;
    if (ref.mounted && current != null) {
      state = AsyncData([
        for (final device in current)
          if (device.isCurrent) device,
      ]);
    }
    return count;
  }
}
