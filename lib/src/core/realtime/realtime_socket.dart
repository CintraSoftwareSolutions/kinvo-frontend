import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../network/api_envelope.dart';
import '../network/api_error_code.dart';

/// The server's reason for refusing a connection, from its handshake check.
@immutable
final class RealtimeRefusal {
  const RealtimeRefusal({required this.code, required this.message});

  /// Reads a refused handshake, which arrives as
  /// `{"message": "...", "data": {"code": "..."}}`. Returns `null` for anything
  /// else, such as a network failure.
  static RealtimeRefusal? tryParse(Object? error) {
    if (error case {
      'message': final String message,
      'data': {'code': final String code},
    }) {
      return RealtimeRefusal(
        code: ApiErrorCode.fromWireValue(code),
        message: message,
      );
    }
    return null;
  }

  /// The same codes the REST API uses.
  final ApiErrorCode code;

  /// Text that can be shown to the user as-is.
  final String message;

  @override
  String toString() => 'RealtimeRefusal(${code.wireValue})';
}

/// What a [RealtimeSocket] reports.
@immutable
final class RealtimeSocketListener {
  const RealtimeSocketListener({
    required this.onConnected,
    required this.onConnectFailed,
    required this.onDisconnected,
    required this.onEvent,
  });

  /// The server accepted the connection.
  final VoidCallback onConnected;

  /// A connection attempt failed: refused by the server, with its reason, or
  /// never reaching it, with `null`.
  final void Function(RealtimeRefusal? refusal) onConnectFailed;

  /// An open connection was lost, other than by [RealtimeSocket.disconnect].
  final VoidCallback onDisconnected;

  /// The server sent [event].
  final void Function(String event, Object? data) onEvent;
}

/// One connection to the server's live events, reduced to what
/// `RealtimeConnection` needs, so tests can stand in for the server.
///
/// It never reconnects by itself. The connection decides when to try again,
/// and hands over a current access token each time.
abstract interface class RealtimeSocket {
  /// Starts connecting, identified by [accessToken].
  void connect(String accessToken);

  /// Closes the connection, or abandons an attempt. Reports nothing further.
  void disconnect();

  /// Sends [event] when connected. Dropped otherwise: everything the app
  /// sends is momentary, like "typing", and has no value delivered late.
  void emit(String event, JsonMap data);

  /// Closes the connection for good.
  void dispose();
}

/// Creates the socket a connection uses, reporting to [listener].
typedef RealtimeSocketFactory =
    RealtimeSocket Function(RealtimeSocketListener listener);

/// [RealtimeSocket] on the Socket.IO server at [server]'s origin.
final class SocketIoRealtimeSocket implements RealtimeSocket {
  SocketIoRealtimeSocket({
    required Uri server,
    required RealtimeSocketListener listener,
  }) : _listener = listener,
       _socket = socket_io.io(
         server.origin,
         socket_io.OptionBuilder()
             .setPath('/socket.io')
             // WebSocket only. Mobile networks handle it well, and it saves
             // the long-polling round trips Socket.IO otherwise starts with.
             .setTransports(['websocket'])
             .disableAutoConnect()
             .disableReconnection()
             // A connection of its own, never a cached one from an earlier
             // session.
             .enableForceNew()
             .setTimeout(connectTimeout.inMilliseconds)
             .build(),
       ) {
    _socket
      ..onConnect((_) => _listener.onConnected())
      ..onConnectError(
        (error) => _listener.onConnectFailed(RealtimeRefusal.tryParse(error)),
      )
      ..onDisconnect((reason) {
        // The app closing the connection itself is not news to the app.
        if (reason != _closedByClient) _listener.onDisconnected();
      })
      ..onAny((event, data) => _listener.onEvent(event, data));
  }

  /// How long an attempt may take before it counts as failed.
  static const connectTimeout = Duration(seconds: 20);

  /// Socket.IO's reason for a disconnect the client asked for.
  static const _closedByClient = 'io client disconnect';

  final RealtimeSocketListener _listener;
  final socket_io.Socket _socket;

  @override
  void connect(String accessToken) {
    _socket
      ..auth = {'token': accessToken}
      ..connect();
  }

  @override
  void disconnect() => _socket.disconnect();

  @override
  void emit(String event, JsonMap data) {
    if (_socket.connected) _socket.emit(event, data);
  }

  @override
  void dispose() => _socket.dispose();
}
