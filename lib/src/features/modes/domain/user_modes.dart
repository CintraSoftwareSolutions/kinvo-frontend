import 'package:flutter/foundation.dart';

import '../../../core/network/api_envelope.dart';
import 'mode_filters.dart';

/// Where the signed-in user stands with one mode.
@immutable
final class UserMode {
  const UserMode({
    required this.mode,
    required this.isEnabled,
    required this.isPrimary,
    required this.canEnable,
    required this.requiresVerification,
    required this.filters,
  });

  /// Reads one mode, as `GET /modes` lists them and `PATCH /modes/{mode}`
  /// returns one.
  static UserMode? tryFromJson(Object? json) {
    if (json is! JsonMap) return null;
    if (json case {
      'mode': final String mode,
      'is_enabled': final bool isEnabled,
      'is_primary': final bool isPrimary,
      'can_enable': final bool canEnable,
      'requires_verification': final bool requiresVerification,
    } when mode.isNotEmpty) {
      if (ModeFilters.tryFromJson(json) case final filters?) {
        return UserMode(
          mode: mode,
          isEnabled: isEnabled,
          isPrimary: isPrimary,
          canEnable: canEnable,
          requiresVerification: requiresVerification,
          filters: filters,
        );
      }
    }
    return null;
  }

  /// The mode's name in the API, for example `study_buddy`.
  final String mode;
  final bool isEnabled;

  /// The mode the app opens in.
  final bool isPrimary;

  /// False when the mode needs something the user doesn't have yet, such as
  /// a verified identity for Cuddle.
  final bool canEnable;

  /// Whether only verified users can switch the mode on.
  final bool requiresVerification;

  /// Who the mode's deck is built from.
  final ModeFilters filters;
}

/// The signed-in user's modes, from `GET /modes`.
@immutable
final class UserModes {
  const UserModes({required this.modes, required this.maxEnabled});

  factory UserModes.fromJson(JsonMap json) {
    if (json case {
      'modes': final List<Object?> modes,
      'max_simultaneous_modes': final int maxEnabled,
    }) {
      return UserModes(
        modes: [for (final mode in modes) ?UserMode.tryFromJson(mode)],
        // The server sends -1 for no limit.
        maxEnabled: maxEnabled < 0 ? null : maxEnabled,
      );
    }
    throw const FormatException('Expected modes and max_simultaneous_modes.');
  }

  final List<UserMode> modes;

  /// How many modes can be on at once, or `null` when there's no limit.
  final int? maxEnabled;

  /// The modes that are on, main mode first.
  List<String> get enabledModes {
    return [
      for (final mode in modes)
        if (mode.isEnabled && mode.isPrimary) mode.mode,
      for (final mode in modes)
        if (mode.isEnabled && !mode.isPrimary) mode.mode,
    ];
  }

  String? get primaryMode {
    return modes.where((mode) => mode.isPrimary).firstOrNull?.mode;
  }

  /// Whether [mode] can be switched on. Modes the server didn't list can't.
  bool canEnable(String mode) => _find(mode)?.canEnable ?? false;

  /// Whether [mode] is out of reach until the user verifies their identity.
  bool needsVerification(String mode) {
    final found = _find(mode);
    return found != null && !found.canEnable && found.requiresVerification;
  }

  UserMode? _find(String mode) {
    return modes.where((each) => each.mode == mode).firstOrNull;
  }
}
