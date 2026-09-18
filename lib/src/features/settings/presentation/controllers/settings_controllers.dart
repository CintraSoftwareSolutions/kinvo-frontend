import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/units/distance.dart';
import '../../data/settings_repository.dart';
import '../../domain/signed_in_device.dart';
import '../../domain/user_settings.dart';

/// The signed-in user's settings.
///
/// Kept for the whole session: the distance unit is read on every card. Starts
/// again when the session changes.
final userSettingsProvider =
    AsyncNotifierProvider<UserSettingsController, UserSettings>(
      UserSettingsController.new,
    );

class UserSettingsController extends AsyncNotifier<UserSettings> {
  @override
  Future<UserSettings> build() {
    ref.watch(sessionStatusProvider);
    return ref.watch(settingsRepositoryProvider).fetchSettings();
  }

  /// Changes the settings given. The change shows at once and is undone if
  /// the server refuses it, which throws an `ApiException`.
  Future<void> change({
    DistanceUnit? distanceUnit,
    bool? showDistance,
    bool? showLastActive,
  }) async {
    final before = state.value;
    if (before == null) return;
    state = AsyncData(
      before.copyWith(
        distanceUnit: distanceUnit,
        showDistance: showDistance,
        showLastActive: showLastActive,
      ),
    );
    try {
      final saved = await ref
          .read(settingsRepositoryProvider)
          .update(
            distanceUnit: distanceUnit,
            showDistance: showDistance,
            showLastActive: showLastActive,
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
