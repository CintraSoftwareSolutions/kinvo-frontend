import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../auth/session_manager.dart';
import '../network/api_envelope.dart';
import '../network/api_error_code.dart';
import 'realtime_events.dart';
import 'realtime_socket.dart';

/// Where the live connection stands.
enum RealtimeStatus {
  /// Closed, because nothing needs it: signed out, or the app is in the
  /// background.
  disconnected,

  /// Wanted but not open yet: connecting, or waiting to try again.
  connecting,

  /// Open. Events arrive as they happen.
  connected,
}

/// The app's one live connection to the server, for chat and other updates
/// that should appear without a refresh.
///
/// It connects while [setWanted] says it's needed, with the session's access
/// token, and handles what can go wrong on the way: an expired token is
/// refreshed and the connection tried again at once, a session the server
/// rejects is ended, and anything else is retried with growing waits.
///
/// Anything that shows live data should read it again whenever [status]
/// becomes [RealtimeStatus.connected]: events sent while the connection was
/// closed are gone.
final class RealtimeConnection {
  RealtimeConnection({
    required SessionManager session,
    required RealtimeSocketFactory createSocket,
    Duration Function(int failures)? retryDelay,
  }) : _session = session,
       _retryDelay = retryDelay ?? defaultRetryDelay {
    _socket = createSocket(
      RealtimeSocketListener(
        onConnected: _handleConnected,
        onConnectFailed: _handleConnectFailed,
        onDisconnected: _handleDisconnected,
        onEvent: _handleEvent,
      ),
    );
  }

  /// How often an open connection tells the server the user is still active.
  /// The server keeps "last active" to within a few minutes, so more often
  /// would only cost battery.
  static const presencePingInterval = Duration(minutes: 1);

  /// The longest wait between attempts.
  static const maxRetryDelay = Duration(seconds: 30);

  static final _random = Random();

  final SessionManager _session;
  final Duration Function(int failures) _retryDelay;
  late final RealtimeSocket _socket;

  final _status = ValueNotifier(RealtimeStatus.disconnected);
  final _events = StreamController<RealtimeEvent>.broadcast();

  bool _wanted = false;
  bool _disposed = false;

  /// Changes whenever an attempt starts or the connection is closed, so the
  /// late result of an abandoned attempt is ignored.
  int _attempt = 0;

  /// Failed attempts in a row, for the wait before the next one.
  int _failures = 0;

  /// The token the current attempt was made with.
  String? _sentToken;

  /// Whether this attempt already refreshed an expired token, so a server
  /// that keeps refusing tokens as expired can't cause a tight loop.
  bool _refreshedForAttempt = false;

  Timer? _retryTimer;
  Timer? _closeTimer;
  Timer? _pingTimer;

  ValueListenable<RealtimeStatus> get status => _status;

  /// Events from the server, as they arrive. Nothing is replayed to late
  /// listeners.
  Stream<RealtimeEvent> get events => _events.stream;

  /// A wait that doubles with each failure from one second up to
  /// [maxRetryDelay], varied a little so phones that lost the server together
  /// don't all come back at the same moment.
  static Duration defaultRetryDelay(int failures) {
    final doubled = 1000 * pow(2, min(failures, 10));
    final varied = doubled * (0.8 + _random.nextDouble() * 0.4);
    return Duration(
      milliseconds: min(varied.round(), maxRetryDelay.inMilliseconds),
    );
  }

  /// Opens the connection when [wanted], and closes it when not.
  ///
  /// Closing can wait for [grace], and is called off if the connection is
  /// wanted again before then. A moment in the photo picker shouldn't show
  /// the user going offline to everyone they've matched with.
  void setWanted(bool wanted, {Duration grace = Duration.zero}) {
    if (_disposed) return;

    if (wanted) {
      _closeTimer?.cancel();
      _closeTimer = null;
      _wanted = true;
      if (_status.value == RealtimeStatus.disconnected) _start();
      return;
    }

    if (!_wanted) return;
    if (grace > Duration.zero) {
      _closeTimer ??= Timer(grace, () {
        _closeTimer = null;
        _close();
      });
      return;
    }
    _close();
  }

  /// Sends [event] if the connection is open. Dropped otherwise, since
  /// everything the app sends is only worth anything right now.
  void send(String event, JsonMap data) {
    if (_disposed || _status.value != RealtimeStatus.connected) return;
    _socket.emit(event, data);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _wanted = false;
    _attempt++;
    _cancelTimers();
    _socket.dispose();
    unawaited(_events.close());
    _status.dispose();
  }

  void _start() {
    final attempt = ++_attempt;
    _refreshedForAttempt = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    _status.value = RealtimeStatus.connecting;
    unawaited(_connectWith(attempt, _session.accessTokenForRequest));
  }

  Future<void> _connectWith(
    int attempt,
    Future<String?> Function() accessToken,
  ) async {
    final String? token;
    try {
      token = await accessToken();
    } on Object catch (error, stackTrace) {
      // Typically offline while the token needed refreshing.
      if (attempt != _attempt || _disposed) return;
      _log('Could not get a token to connect with.', error, stackTrace);
      _retryLater();
      return;
    }
    if (attempt != _attempt || _disposed) return;

    if (token == null) {
      // The session ended, and with it the reason to connect.
      _halt();
      return;
    }
    _sentToken = token;
    _socket.connect(token);
  }

  void _handleConnected() {
    if (_disposed) return;
    if (!_wanted) {
      _socket.disconnect();
      return;
    }
    _failures = 0;
    _status.value = RealtimeStatus.connected;
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(presencePingInterval, (_) {
      send(ClientEvents.presencePing, const {});
    });
  }

  void _handleConnectFailed(RealtimeRefusal? refusal) {
    if (_disposed || !_wanted) return;

    switch (refusal) {
      case RealtimeRefusal(code: ApiErrorCode.authTokenExpired):
        // Routine: refresh, and go straight back in.
        final rejected = _sentToken;
        if (rejected != null && !_refreshedForAttempt) {
          _refreshedForAttempt = true;
          unawaited(
            _connectWith(
              _attempt,
              () => _session.accessTokenAfterExpiry(rejected),
            ),
          );
        } else {
          _retryLater();
        }
      case RealtimeRefusal(code: ApiErrorCode.authTokenInvalid):
        // Ending the session sends the user to sign in, which also stops
        // this connection being wanted.
        if (_sentToken case final rejected?) {
          unawaited(_session.handleRejectedSession(rejected));
        }
        _halt();
      case RealtimeRefusal(code: ApiErrorCode.accountSuspended, :final message):
        _session.handleAccountSuspended(message);
        _halt();
      case RealtimeRefusal(code: ApiErrorCode.onboardingIncomplete):
        // The app waits for onboarding before connecting, so the server
        // disagrees about the account. Asking again won't change its mind;
        // the next time the connection is wanted, it tries afresh.
        _halt();
      case _:
        _retryLater();
    }
  }

  void _handleDisconnected() {
    if (_disposed) return;
    _pingTimer?.cancel();
    _pingTimer = null;
    if (_wanted) {
      _retryLater();
    } else {
      _status.value = RealtimeStatus.disconnected;
    }
  }

  void _handleEvent(String name, Object? data) {
    if (_disposed) return;
    if (data is! JsonMap) {
      // Every event in the contract carries an object.
      developer.log('Ignored "$name" without an object.', name: _logName);
      return;
    }
    if (name == ServerEvents.error) {
      developer.log('The server refused an event: $data', name: _logName);
    }
    _events.add(RealtimeEvent(name, data));
  }

  void _retryLater() {
    _status.value = RealtimeStatus.connecting;
    final delay = _retryDelay(_failures);
    _failures++;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (_wanted && !_disposed) _start();
    });
  }

  /// Closes the connection because it's no longer wanted.
  void _close() {
    _wanted = false;
    _halt();
  }

  /// Closes the connection and stops trying until it's next wanted.
  void _halt() {
    _attempt++;
    _failures = 0;
    _sentToken = null;
    _cancelTimers();
    _socket.disconnect();
    _status.value = RealtimeStatus.disconnected;
  }

  void _cancelTimers() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _closeTimer?.cancel();
    _closeTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  static const _logName = 'kinvo.realtime';

  static void _log(String message, Object error, StackTrace stackTrace) {
    developer.log(
      message,
      name: _logName,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
