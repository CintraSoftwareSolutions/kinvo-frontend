import 'package:flutter/foundation.dart';

import '../../../core/config/server_config.dart';
import '../../discovery/domain/discovery_formatting.dart';
import 'user_modes.dart';

/// One mode as the user can choose it: named from the server's catalogue,
/// with where the account stands with it.
@immutable
final class ModeChoice {
  const ModeChoice({
    required this.value,
    required this.label,
    required this.description,
    required this.isOn,
    required this.isMain,
    required this.canEnable,
    required this.needsVerification,
  });

  /// The mode's name in the API, for example `study_buddy`.
  final String value;
  final String label;

  /// What the mode is for, in the catalogue's words. Empty for a mode the
  /// catalogue doesn't describe.
  final String description;

  /// Whether the mode is switched on.
  final bool isOn;

  /// Whether it's the main mode: the one the app opens in.
  final bool isMain;

  /// Whether it may be switched on. False when it needs something the user
  /// doesn't have yet.
  final bool canEnable;

  /// Whether what it needs is a verified identity, so the user can be
  /// pointed there.
  final bool needsVerification;

  /// Off, and nothing the user can do here would switch it on.
  bool get isUnavailable => !isOn && !canEnable && !needsVerification;
}

/// Every mode in the server's catalogue, in the catalogue's order, with
/// where [modes] stands with each. A mode the account has but the catalogue
/// doesn't list, which only a server newer than its own catalogue could
/// send, comes last, named from its API name.
List<ModeChoice> modeChoicesFrom(UserModes modes, ServerConfig config) {
  final byValue = {for (final mode in modes.modes) mode.mode: mode};

  ModeChoice choice(String value, String label, String description) {
    final mode = byValue[value];
    return ModeChoice(
      value: value,
      label: label,
      description: description,
      isOn: mode?.isEnabled ?? false,
      isMain: mode?.isPrimary ?? false,
      canEnable: mode?.canEnable ?? false,
      needsVerification: modes.needsVerification(value),
    );
  }

  final catalogued = {for (final option in config.modes) option.value};
  return [
    for (final option in config.modes)
      choice(option.value, option.label, option.description),
    for (final mode in modes.modes)
      if (!catalogued.contains(mode.mode) && mode.isEnabled)
        choice(mode.mode, humanise(mode.mode), ''),
  ];
}
