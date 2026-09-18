import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../../core/config/server_config.dart';
import '../../../../core/config/server_config_providers.dart';
import '../../../../core/demo/demo_mode.dart';
import '../../data/discovery_repository.dart';
import '../../domain/discovery_formatting.dart';
import '../../domain/discovery_mode.dart';

/// The modes Discover can show: the ones the user has switched on, main mode
/// first.
final discoveryModesProvider = FutureProvider.autoDispose<List<DiscoveryMode>>(
  (ref) => ref.watch(discoveryRepositoryProvider).fetchModes(),
);

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

/// Interest labels by slug, from the server's catalogue.
///
/// Empty in the demo, which runs without a connection and names interests
/// from their slugs, and while the catalogue loads.
final interestLabelsProvider = Provider.autoDispose<Map<String, String>>((ref) {
  if (ref.watch(demoSessionProvider)) return const {};
  final config = ref.watch(serverConfigProvider).value;
  return {
    for (final interest in config?.interests ?? const <InterestOption>[])
      interest.slug: interest.label,
  };
});

/// A mode's label, by its API name: from the user's modes, then the server's
/// catalogue, and otherwise made from the name itself.
///
/// The catalogue is only read outside the demo, which has no connection.
final modeLabelProvider = Provider.autoDispose.family<String, String>((
  ref,
  mode,
) {
  final modes = ref.watch(discoveryModesProvider).value ?? const [];
  for (final each in modes) {
    if (each.value == mode) return each.label;
  }
  if (!ref.watch(demoSessionProvider)) {
    final config = ref.watch(serverConfigProvider).value;
    for (final option in config?.modes ?? const <ModeOption>[]) {
      if (option.value == mode) return option.label;
    }
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
