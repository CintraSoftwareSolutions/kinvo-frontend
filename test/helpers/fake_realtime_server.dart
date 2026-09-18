import 'dart:async';

import 'package:kinvo/src/core/network/api_envelope.dart';
import 'package:kinvo/src/core/realtime/realtime_socket.dart';

/// The server's live connection, for tests: it decides whether the app may
/// connect, records what the app sends, and pushes events to it.
final class FakeRealtimeServer {
  /// Decides each connection attempt by its access token: a refusal refuses
  /// it, `null` accepts it. Accepts everything when unset.
  RealtimeRefusal? Function(String accessToken)? refuse;

  /// Whether attempts reach the server. When false they fail as a lost
  /// network would.
  bool reachable = true;

  /// Every socket the app created, oldest first.
  final List<FakeRealtimeSocket> sockets = [];

  /// The access token of every connection attempt, in order.
  final List<String> attempts = [];

  /// Everything the app sent over an open connection, in order.
  final List<({String event, JsonMap data})> received = [];

  /// Creates the app's socket. Pass this as the socket factory.
  RealtimeSocket createSocket(RealtimeSocketListener listener) {
    final socket = FakeRealtimeSocket._(this, listener);
    sockets.add(socket);
    return socket;
  }

  /// Whether the app has a connection open.
  bool get isConnected => sockets.any((socket) => socket.isConnected);

  /// Sends [event] down every open connection.
  void push(String event, JsonMap data) {
    for (final socket in [...sockets]) {
      if (socket.isConnected) socket._listener.onEvent(event, data);
    }
  }

  /// Loses every open connection, as a dropped network would.
  void dropConnections() {
    for (final socket in [...sockets]) {
      if (!socket.isConnected) continue;
      socket.isConnected = false;
      socket._listener.onDisconnected();
    }
  }

  /// The data of each [event] the app sent, in order.
  List<JsonMap> sent(String event) {
    return [
      for (final message in received)
        if (message.event == event) message.data,
    ];
  }
}

final class FakeRealtimeSocket implements RealtimeSocket {
  FakeRealtimeSocket._(this._server, this._listener);

  final FakeRealtimeServer _server;
  final RealtimeSocketListener _listener;

  bool isConnected = false;
  bool isDisposed = false;

  /// Changes whenever an attempt starts or is abandoned, so an abandoned
  /// attempt never reports back.
  int _attempt = 0;

  @override
  void connect(String accessToken) {
    final attempt = ++_attempt;
    _server.attempts.add(accessToken);
    // Answered after a moment, as a real handshake is.
    scheduleMicrotask(() {
      if (attempt != _attempt || isDisposed) return;
      if (!_server.reachable) {
        _listener.onConnectFailed(null);
      } else if (_server.refuse?.call(accessToken) case final refusal?) {
        _listener.onConnectFailed(refusal);
      } else {
        isConnected = true;
        _listener.onConnected();
      }
    });
  }

  @override
  void disconnect() {
    _attempt++;
    isConnected = false;
  }

  @override
  void emit(String event, JsonMap data) {
    if (isConnected) _server.received.add((event: event, data: data));
  }

  @override
  void dispose() {
    disconnect();
    isDisposed = true;
  }
}
