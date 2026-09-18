import 'dart:async';
import 'dart:developer' as developer;

import '../device/client_info.dart';
import '../network/api_client.dart';
import 'push_messaging.dart';

/// Keeps the server's record of this device's push token in step with the
/// device: registered while notifications are allowed, removed while they
/// aren't, so the server only sends what can be shown.
final class PushTokenRegistrar {
  PushTokenRegistrar({
    required PushMessaging messaging,
    required ApiClient api,
    required Future<ClientInfo> Function() clientInfo,
  }) : _messaging = messaging,
       _api = api,
       _clientInfo = clientInfo;

  final PushMessaging _messaging;
  final ApiClient _api;
  final Future<ClientInfo> Function() _clientInfo;

  /// The token the server holds for this device, as far as this run knows.
  String? _registered;

  /// Whether the server was told, this run, not to send to this device.
  bool _cleared = false;

  Future<void>? _inFlight;
  bool _runAgain = false;

  /// Brings the server in line with the device. Call it whenever something
  /// that decides this might have changed; calls made while one is running
  /// fold into a single further run.
  Future<void> sync() {
    if (!_messaging.isAvailable) return Future.value();
    if (_inFlight case final running?) {
      _runAgain = true;
      return running;
    }
    return _inFlight = _run().whenComplete(() => _inFlight = null);
  }

  /// Forgets this device's token once the session has ended, so nothing meant
  /// for that account reaches the device, and whoever signs in next gets a
  /// token of their own. The server stops using the old one when it hears
  /// it's gone.
  Future<void> signedOut() async {
    if (!_messaging.isAvailable) return;
    _registered = null;
    _cleared = false;
    await _messaging.deleteToken();
  }

  Future<void> _run() async {
    do {
      _runAgain = false;
      await _syncOnce();
    } while (_runAgain);
  }

  Future<void> _syncOnce() async {
    try {
      if (await _messaging.permission() != PushPermission.granted) {
        if (_cleared) return;
        final deviceId = (await _clientInfo()).deviceId;
        await _api.delete(
          '/notifications/tokens/${Uri.encodeComponent(deviceId)}',
          decode: ApiClient.ignoreData,
        );
        _registered = null;
        _cleared = true;
        return;
      }

      final token = await _messaging.token();
      if (token == null || token == _registered) return;
      final deviceId = (await _clientInfo()).deviceId;
      await _api.post(
        '/notifications/tokens',
        body: {'device_id': deviceId, 'fcm_token': token},
        decode: ApiClient.ignoreData,
      );
      _registered = token;
      _cleared = false;
    } on Object catch (error, stackTrace) {
      // Typically offline. The next change, or the app coming back to the
      // screen, tries again.
      developer.log(
        'Could not update the push token.',
        name: 'kinvo.push',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
