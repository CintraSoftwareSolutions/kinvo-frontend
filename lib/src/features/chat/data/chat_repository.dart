import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/account_providers.dart';
import '../../../core/demo/demo_mode.dart';
import '../../../core/media/media_uploader.dart';
import '../../../core/media/photo_processing.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/cursor_page.dart';
import '../../../core/time/clock.dart';
import '../../matches/data/demo_inbox.dart';
import '../domain/chat_message.dart';
import '../domain/conversation.dart';
import '../domain/moderation_check.dart';
import 'demo_chat_repository.dart';

/// Everything chat reads from the server and sends to it.
///
/// An interface because the demo shows the same screens without an account,
/// on [DemoChatRepository]. Failures are `ApiException`s.
abstract interface class ChatRepository {
  Future<Conversation> fetchConversation(String conversationId);

  /// One page of messages, newest first. Pass the previous page's cursor to
  /// go further back.
  Future<CursorPage<ChatMessage>> fetchMessages(
    String conversationId, {
    String? cursor,
  });

  /// Sends [text]. [moderationOverridden] records that the user sent it after
  /// being warned about it.
  ///
  /// [clientToken] names this message until the server gives it an id. A
  /// send that times out has often arrived anyway, so trying again with the
  /// same token gets the message that exists rather than sending a second.
  Future<ChatMessage> sendText(
    String conversationId,
    String text, {
    required bool moderationOverridden,
    required String clientToken,
  });

  /// Uploads [photo] for sending, returning the upload's id.
  Future<String> uploadPhoto(PreparedPhoto photo);

  /// Sends the photo uploaded as [uploadId], named by [clientToken] as
  /// [sendText] is.
  Future<ChatMessage> sendPhoto(
    String conversationId,
    String uploadId, {
    required String clientToken,
  });

  /// Marks everything in the conversation read, which the other person sees.
  Future<void> markRead(String conversationId);

  Future<Conversation> updateConversation(
    String conversationId, {
    bool? isArchived,
    bool? isMuted,
  });

  /// Unread messages across every conversation.
  Future<int> fetchUnreadCount();

  /// Asks the server whether [text] deserves a second look before sending.
  Future<ModerationCheck> checkMessage(String text);
}

/// [ChatRepository] on the Kinvo API.
final class ApiChatRepository implements ChatRepository {
  const ApiChatRepository({
    required ApiClient api,
    required MediaUploader uploader,
  }) : _api = api,
       _uploader = uploader;

  static const pageSize = 30;

  final ApiClient _api;
  final MediaUploader _uploader;

  @override
  Future<Conversation> fetchConversation(String conversationId) {
    return _api.get(_path(conversationId), decode: Conversation.fromJson);
  }

  @override
  Future<CursorPage<ChatMessage>> fetchMessages(
    String conversationId, {
    String? cursor,
  }) {
    return _api.getPage(
      '${_path(conversationId)}/messages',
      decodeItem: ChatMessage.fromJson,
      cursor: cursor,
      limit: pageSize,
    );
  }

  @override
  Future<ChatMessage> sendText(
    String conversationId,
    String text, {
    required bool moderationOverridden,
    required String clientToken,
  }) {
    return _api.post(
      '${_path(conversationId)}/messages',
      body: {
        'type': MessageKind.text.wireValue,
        'body': text,
        'client_token': clientToken,
        if (moderationOverridden) 'moderation_overridden': true,
      },
      decode: ChatMessage.fromJson,
    );
  }

  @override
  Future<String> uploadPhoto(PreparedPhoto photo) {
    return _uploader.upload(
      purpose: UploadPurpose.chatImage,
      bytes: photo.bytes,
      mimeType: PreparedPhoto.mimeType,
    );
  }

  @override
  Future<ChatMessage> sendPhoto(
    String conversationId,
    String uploadId, {
    required String clientToken,
  }) {
    return _api.post(
      '${_path(conversationId)}/messages',
      body: {
        'type': MessageKind.image.wireValue,
        'media_asset_id': uploadId,
        'client_token': clientToken,
      },
      decode: ChatMessage.fromJson,
    );
  }

  @override
  Future<void> markRead(String conversationId) {
    return _api.post(
      '${_path(conversationId)}/read',
      decode: ApiClient.ignoreData,
    );
  }

  @override
  Future<Conversation> updateConversation(
    String conversationId, {
    bool? isArchived,
    bool? isMuted,
  }) {
    return _api.patch(
      _path(conversationId),
      body: {'is_archived': ?isArchived, 'is_muted': ?isMuted},
      decode: Conversation.fromJson,
    );
  }

  @override
  Future<int> fetchUnreadCount() {
    return _api.get('/conversations/unread-count', decode: _readUnreadCount);
  }

  @override
  Future<ModerationCheck> checkMessage(String text) {
    return _api.post(
      '/moderation/check',
      body: {'content': text, 'subject_type': 'message'},
      decode: ModerationCheck.fromJson,
    );
  }

  static String _path(String conversationId) {
    return '/conversations/${Uri.encodeComponent(conversationId)}';
  }

  static int _readUnreadCount(JsonMap json) {
    if (json case {'unread_count': final int count} when count >= 0) {
      return count;
    }
    throw const FormatException('Expected a non-negative unread_count.');
  }
}

/// The repository chat uses: the demo's while exploring it, the API's
/// otherwise.
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  if (ref.watch(demoSessionProvider)) {
    return DemoChatRepository(
      inbox: ref.watch(demoInboxProvider),
      clock: ref.watch(clockProvider),
    );
  }
  return ApiChatRepository(
    api: ref.watch(apiClientProvider),
    uploader: ref.watch(mediaUploaderProvider),
  );
});

/// The user's id, as messages name their sender. In the demo, the demo's
/// stand-in for the user.
final chatUserIdProvider = Provider<String?>((ref) {
  if (ref.watch(demoSessionProvider)) return DemoChatRepository.userId;
  return ref.watch(currentAccountProvider).value?.id;
});
