import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/async/wait_both.dart';
import '../../../../core/auth/auth_providers.dart';
import '../../../../core/config/server_config.dart';
import '../../../../core/config/server_config_providers.dart';
import '../../../modes/presentation/controllers/user_modes_controller.dart';
import '../../data/discovery_repository.dart';
import '../../domain/discovery_formatting.dart';
import '../../domain/discovery_mode.dart';

/// The modes Discover can show: the ones the user has switched on, main mode
/// first, named from the server's catalogue.
///
/// Follows [userModesProvider], so a mode switched on or off anywhere in the
/// app is on Discover at once.
final discoveryModesProvider = FutureProvider.autoDispose<List<DiscoveryMode>>((
  ref,
) async {
  // Both watched before anything is awaited: after an await the provider may
  // already be gone, and watching then throws.
  final (modes, config) = await waitBoth(
    ref.watch(userModesProvider.future),
    ref.watch(serverConfigProvider.future),
  );
  return discoveryModesFrom(modes, config);
});

/// Reads the modes again after a failure, and the catalogue too if that is
/// what failed.
void retryDiscoveryModes(WidgetRef ref) {
  if (ref.read(serverConfigProvider).hasError) {
    ref.invalidate(serverConfigProvider);
  }
  ref.invalidate(userModesProvider);
}

/// The mode the user last picked on Discover, by its API name, or `null`
/// before they pick one.
///
/// Starts again when the session changes, so one account's choice never
/// carries over to the next.
final selectedDiscoveryModeProvider =
    NotifierProvider<SelectedDiscoveryModeController, String?>(
      SelectedDiscoveryModeController.new,
    );

class SelectedDiscoveryModeController extends Notifier<String?> {
  @override
  String? build() {
    ref
      ..watch(sessionStatusProvider)
      ..watch(discoveryRepositoryProvider);
    return null;
  }

  void select(String mode) => state = mode;
}

/// Interest labels by slug, from the server's catalogue. Empty while the
/// catalogue loads.
final interestLabelsProvider = Provider.autoDispose<Map<String, String>>((ref) {
  final config = ref.watch(serverConfigProvider).value;
  return {
    for (final interest in config?.interests ?? const <InterestOption>[])
      interest.slug: interest.label,
  };
});

/// A mode's label, by its API name: from the user's modes, then the server's
/// catalogue, and otherwise made from the name itself.
final modeLabelProvider = Provider.autoDispose.family<String, String>((
  ref,
  mode,
) {
  final modes = ref.watch(discoveryModesProvider).value ?? const [];
  for (final each in modes) {
    if (each.value == mode) return each.label;
  }
  final config = ref.watch(serverConfigProvider).value;
  for (final option in config?.modes ?? const <ModeOption>[]) {
    if (option.value == mode) return option.label;
  }
  return humanise(mode);
});

/// The mode Discover is showing: the one picked, while it's still switched
/// on, and otherwise the main mode.
///
/// `null` once loaded means no mode is switched on, which onboarding normally
/// rules out but another device can undo.
final activeDiscoveryModeProvider =
    Provider.autoDispose<AsyncValue<DiscoveryMode?>>((ref) {
      final selected = ref.watch(selectedDiscoveryModeProvider);
      return ref.watch(discoveryModesProvider).whenData((modes) {
        return modes.where((mode) => mode.value == selected).firstOrNull ??
            modes.firstOrNull;
      });
    });
