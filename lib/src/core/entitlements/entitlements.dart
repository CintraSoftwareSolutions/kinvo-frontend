import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../auth/session_status.dart';
import '../demo/demo_mode.dart';
import '../network/api_client.dart';
import '../network/api_client_provider.dart';
import '../network/api_envelope.dart';
import '../realtime/realtime_events.dart';
import '../realtime/realtime_providers.dart';

/// What the account's plan unlocks, from `GET /entitlements`.
///
/// Read as flags, never as a plan's name: which plan unlocks what is data on
/// the server (spec §5.11), and several of its rows are still being decided —
/// so the app asks "may this account do X", and a feature moved between plans
/// needs no release.
@immutable
final class Entitlements {
  const Entitlements({required this.flags, required this.upgradeAvailable});

  factory Entitlements.fromJson(JsonMap json) {
    if (json case {'flags': final JsonMap flags}) {
      return Entitlements(
        flags: Map.unmodifiable(flags),
        upgradeAvailable: json['upgrade_available'] != false,
      );
    }
    throw const FormatException('Expected flags.');
  }

  /// Nothing known yet, or it couldn't be read: every feature off — and no
  /// ads, because an account whose plan couldn't be read may be one that paid
  /// to be rid of them.
  static const unknown = Entitlements(flags: {}, upgradeAvailable: false);

  final Map<String, Object?> flags;

  /// Whether a higher plan exists to offer.
  final bool upgradeAvailable;

  /// Whether this account is shown ads. Only an explicit `true` counts.
  bool get showAds => flags['show_ads'] == true;
}

abstract interface class EntitlementsRepository {
  Future<Entitlements> fetch();
}

final class ApiEntitlementsRepository implements EntitlementsRepository {
  const ApiEntitlementsRepository(this._api);

  final ApiClient _api;

  @override
  Future<Entitlements> fetch() {
    return _api.get('/entitlements', decode: Entitlements.fromJson);
  }
}

final entitlementsRepositoryProvider = Provider<EntitlementsRepository>((ref) {
  return ApiEntitlementsRepository(ref.watch(apiClientProvider));
});

/// The signed-in account's entitlements, for the whole session.
///
/// Read again the moment the server says the plan changed — a purchase here
/// or on another phone, a plan running out — so what the plan unlocks, and
/// whether ads show, follows the plan without a restart.
final entitlementsProvider =
    AsyncNotifierProvider<EntitlementsController, Entitlements>(
      EntitlementsController.new,
    );

class EntitlementsController extends AsyncNotifier<Entitlements> {
  @override
  Future<Entitlements> build() async {
    final session = ref.watch(sessionStatusProvider);

    // Signed out, or the demo, which never touches the network: nothing to
    // read, and nothing unlocked.
    if (session is! SignedIn || ref.watch(demoSessionProvider)) {
      return Entitlements.unknown;
    }

    final events = ref.watch(realtimeConnectionProvider).events.listen((event) {
      if (event.name == ServerEvents.entitlementsUpdated) unawaited(refresh());
    });
    ref.onDispose(() => unawaited(events.cancel()));

    return ref.watch(entitlementsRepositoryProvider).fetch();
  }

  /// Reads the entitlements again. A failure keeps what was known: the right
  /// answer a moment ago beats no answer.
  Future<void> refresh() async {
    try {
      final latest = await ref.read(entitlementsRepositoryProvider).fetch();
      if (ref.mounted) state = AsyncData(latest);
    } on Object catch (error, stackTrace) {
      if (ref.mounted && !state.hasValue) state = AsyncError(error, stackTrace);
    }
  }
}
