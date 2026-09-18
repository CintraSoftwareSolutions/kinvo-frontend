import 'package:flutter/foundation.dart';

import '../network/api_envelope.dart';

/// Something the server sent over the live connection.
///
/// Every event describes a change the server has already saved, so a missed
/// one costs a refresh, never data. Features read the payloads they care
/// about; see [ServerEvents] for the names.
@immutable
final class RealtimeEvent {
  const RealtimeEvent(this.name, this.data);

  final String name;
  final JsonMap data;

  @override
  String toString() => 'RealtimeEvent($name)';
}

/// Events the server sends, as named in its realtime contract.
abstract final class ServerEvents {
  /// A message arrived in one of the user's conversations.
  static const messageNew = 'message:new';

  /// The other person in a conversation read it.
  static const messageRead = 'message:read';

  /// The other person in a conversation started or stopped typing.
  static const typing = 'typing';

  /// Someone liked the user back and made a match.
  static const matchNew = 'match:new';

  /// A conversation's unread count or last message changed.
  static const conversationUpdated = 'conversation:updated';

  /// Someone the user has a match with came online or went offline.
  static const presenceUpdate = 'presence:update';

  /// The user's plan changed.
  static const entitlementsUpdated = 'entitlements:updated';

  /// A notification was added to the user's feed.
  static const notificationNew = 'notification:new';

  /// The server couldn't act on an event the app sent.
  static const error = 'error';
}

/// Events the app sends.
abstract final class ClientEvents {
  static const typingStart = 'typing:start';
  static const typingStop = 'typing:stop';

  /// Keeps the user's "last active" time current while the app is open.
  static const presencePing = 'presence:ping';
}
