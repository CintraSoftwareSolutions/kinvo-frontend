import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_providers.dart';
import '../auth/session_status.dart';

/// Whether this build lets people explore the app on sample data without an
/// account.
///
/// On only in builds made with `DEMO_MODE_ENABLED=true`, as `env/staging.json`
/// does. Production builds leave it off.
final demoModeAvailableProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('DEMO_MODE_ENABLED'),
);

/// Whether the user is exploring the demo. Ends as soon as a real session
/// starts.
final demoSessionProvider = NotifierProvider<DemoSessionController, bool>(
  DemoSessionController.new,
);

class DemoSessionController extends Notifier<bool> {
  @override
  bool build() {
    ref.listen(sessionStatusProvider, (_, status) {
      if (status is SignedIn) state = false;
    });
    return false;
  }

  /// Starts the demo. Returns `false` when this build doesn't offer one or a
  /// real session is active.
  bool start() {
    if (!ref.read(demoModeAvailableProvider)) return false;
    if (ref.read(sessionStatusProvider) is! SignedOut) return false;
    state = true;
    return true;
  }

  /// Leaves the demo.
  void end() => state = false;
}

/// Shows [child] only in builds that offer the demo.
///
/// For entry points into flows that aren't connected to the backend yet, such
/// as social sign-in, so a production build never leads into a prototype.
class DemoOnly extends ConsumerWidget {
  const DemoOnly({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(demoModeAvailableProvider)
        ? child
        : const SizedBox.shrink();
  }
}

/// Finishes a flow that isn't connected to the backend yet by continuing in
/// the demo at [destination]. Returns whether it did; otherwise the user is
/// told the flow isn't available.
///
/// Phone and social sign-in still run on sample data. Each call to this is
/// replaced by the real API flow as that screen is connected.
bool continueInDemo(
  BuildContext context,
  WidgetRef ref, {
  required String destination,
}) {
  if (ref.read(demoSessionProvider.notifier).start()) {
    context.go(destination);
    return true;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text("This isn't available yet.")));
  return false;
}
