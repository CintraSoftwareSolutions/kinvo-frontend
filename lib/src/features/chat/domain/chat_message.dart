import 'package:flutter/foundation.dart';

import '../../../core/network/api_envelope.dart';

/// What a message holds.
enum MessageKind {
  text('text'),
  image('image'),
  video('video'),
  voiceNote('voice_note'),

  /// A place suggested for meeting up.
  venueCard('venue_card'),

  /// A kind added to the server after this version of the app.
  unsupported('');

  const MessageKind(this.wireValue);

  /// The value as it appears in a message's `type`.
  final String wireValue;

  static MessageKind fromWireValue(String value) {
    for (final kind in values) {
      if (kind != unsupported && kind.wireValue == value) return kind;
    }
    return unsupported;
  }
}

/// A message in a conversation, as the server stored it.
@immutable
final class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.kind,
    required this.body,
    required this.mediaUrl,
    required this.duration,
    required this.isFlagged,
    required this.readAt,
    required this.createdAt,
  });

  /// Reads a message, as `GET /conversations/{id}/messages` lists them,
  /// sending returns one, and the `message:new` event carries one.
  factory ChatMessage.fromJson(JsonMap json) {
    if (json case {
      'id': final String id,
      'conversation_id': final String conversationId,
      'sender_id': final String senderId,
      'type': final String type,
      'body': final String? body,
      'media_url': final String? mediaUrl,
      'duration_ms': final int? durationMs,
      'moderation_flagged': final bool isFlagged,
      'read_at': final String? readAt,
      'created_at': final String createdAt,
    } when id.isNotEmpty && conversationId.isNotEmpty && senderId.isNotEmpty) {
      final created = DateTime.tryParse(createdAt);
      final read = readAt == null ? null : DateTime.tryParse(readAt);
      if (created != null && (readAt == null || read != null)) {
        return ChatMessage(
          id: id,
          conversationId: conversationId,
          senderId: senderId,
          kind: MessageKind.fromWireValue(type),
          body: body,
          mediaUrl: mediaUrl == null ? null : Uri.tryParse(mediaUrl),
          duration: durationMs == null
              ? null
              : Duration(milliseconds: durationMs),
          isFlagged: isFlagged,
          readAt: read,
          createdAt: created,
        );
      }
    }
    throw const FormatException(
      'Expected a message with id, conversation_id, sender_id, type, body, '
      'media_url, duration_ms, moderation_flagged, read_at and created_at.',
    );
  }

  final String id;
  final String conversationId;
  final String senderId;
  final MessageKind kind;

  /// The text of a text message.
  final String? body;

  /// The photo or recording. The link expires, and every read gives a new
  /// one.
  final Uri? mediaUrl;

  /// How long a voice note or video lasts.
  final Duration? duration;

  /// Kinvo's moderation found something in it worth a warning, such as a
  /// request for money.
  final bool isFlagged;

  /// When the other person read it, or `null` while they haven't.
  final DateTime? readAt;

  final DateTime createdAt;

  /// How it's summed up in a list of conversations, as the server does.
  String get preview {
    return switch (kind) {
      MessageKind.text => body ?? '',
      MessageKind.image => 'Photo',
      MessageKind.video => 'Video',
      MessageKind.voiceNote => 'Voice note',
      MessageKind.venueCard => 'Suggested a place',
      MessageKind.unsupported => 'Message',
    };
  }

  /// This message, read at [at].
  ChatMessage readAtTime(DateTime at) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      kind: kind,
      body: body,
      mediaUrl: mediaUrl,
      duration: duration,
      isFlagged: isFlagged,
      readAt: at,
      createdAt: createdAt,
    );
  }
}
