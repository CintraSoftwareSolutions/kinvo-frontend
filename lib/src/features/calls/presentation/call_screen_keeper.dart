import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_router.dart';
import '../../../core/navigation/app_routes.dart';
import 'controllers/call_controller.dart';

/// Opens the call screen when a call starts, and closes it when the call is
/// over. Listen to this once, for as long as the app runs.
///
/// A call arrives while the user is anywhere — reading a chat, in Discover, or
/// on the Plans tab — so nothing on any of those screens can be responsible
/// for showing it. It is pushed onto the root navigator, over the tabs.
final callScreenKeeperProvider = Provider<void>((ref) {
  var showing = false;

  ref.listen<ActiveCall?>(callControllerProvider, (previous, next) {
    if (next != null && !showing) {
      showing = true;
      ref.read(appRouterProvider).push(AppRoutes.call);
      return;
    }

    // Closing is the screen's own job: it is the route, so it is the only
    // thing that can be certain it is popping itself and not whatever a
    // sign-out or a deep link put on top of it.
    if (next == null) showing = false;
  });
});
