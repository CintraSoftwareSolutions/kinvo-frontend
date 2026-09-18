import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide AsyncError;

import '../../../../core/entitlements/paywall.dart';
import '../../../../core/media/photo_processing.dart';
import '../../../../core/network/api_error_code.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/cursor_page.dart';
import '../../../../core/realtime/realtime_connection.dart';
import '../../../../core/realtime/realtime_events.dart';
import '../../../../core/realtime/realtime_providers.dart';
import '../../../../core/time/clock.dart';
import '../../../matches/data/matches_repository.dart';
import '../../../matches/presentation/controllers/matches_controllers.dart';
import '../../../safety/data/safety_repository.dart';
import '../../data/chat_repository.dart';
import '../../data/live_updates.dart';
import '../../domain/chat_message.dart';
import '../../domain/conversation.dart';
import '../../domain/live_update.dart';
import '../../domain/moderation_check.dart';

/// Where a message the user sent stands before the server has it.
enum OutgoingStatus { sending, failed }

/// A message the user sent that the server doesn't have yet.
@immutable
final class OutgoingMessage {
  const OutgoingMessage({
    required this.localId,
    required this.status,
    this.text,
    this.photo,
    this.uploadId,
    this.moderationOverridden = false,
    this.failure,
  });

  /// Names it on this device until the server gives it an id.
  final String localId;

  final OutgoingStatus status;

  /// What a text message says.
  final String? text;

  /// The photo of a photo message.
  final PreparedPhoto? photo;

  /// The photo's finished upload, kept so trying again doesn't upload it
  /// twice.
  final String? uploadId;

  /// Whether the user sent it after being warned about it.
  final bool moderationOverridden;

  /// Why it failed, in words for the user.
  final String? failure;

  OutgoingMessage copyWith({
    OutgoingStatus? status,
    String? uploadId,
    ValueGetter<String?>? failure,
  }) {
    return OutgoingMessage(
      localId: localId,
      status: status ?? this.status,
      text: text,
      photo: photo,
      uploadId: uploadId ?? this.uploadId,
      moderationOverridden: moderationOverridden,
      failure: failure == null ? this.failure : failure(),
    );
  }
}

/// A conversation as the chat screen shows it.
@immutable
final class ChatThread {
  const ChatThread({
    required this.userId,
    required this.conversation,
    required this.messages,
    required this.olderCursor,
    required this.hasOlder,
    this.outgoing = const [],
    this.isLoadingOlder = false,
    this.loadOlderFailed = false,
    this.peerIsTyping = false,
    this.localPhotos = const {},
  });

  /// The user's id, which tells their messages from the other person's.
  final String userId;

  final Conversation conversation;

  /// Messages the server has, newest first.
  final List<ChatMessage> messages;

  /// Messages on their way, oldest first. They come after every message in
  /// [messages].
  final List<OutgoingMessage> outgoing;

  final String? olderCursor;
  final bool hasOlder;
  final bool isLoadingOlder;
  final bool loadOlderFailed;

  /// Whether the other person is typing.
  final bool peerIsTyping;

  /// Photos sent from this device, by message id, so they show straight away
  /// instead of downloading what was just uploaded.
  final Map<String, PreparedPhoto> localPhotos;

  bool isMine(ChatMessage message) => message.senderId == userId;

  /// Whether the other person sent anything the user hasn't read.
  bool get hasUnread {
    return conversation.unreadCount > 0 ||
        messages.any((message) => !isMine(message) && message.readAt == null);
  }

  ChatThread copyWith({
    Conversation? conversation,
    List<ChatMessage>? messages,
    List<OutgoingMessage>? outgoing,
    ValueGetter<String?>? olderCursor,
    bool? hasOlder,
    bool? isLoadingOlder,
    bool? loadOlderFailed,
    bool? peerIsTyping,
    Map<String, PreparedPhoto>? localPhotos,
  }) {
    return ChatThread(
      userId: userId,
      conversation: conversation ?? this.conversation,
      messages: messages ?? this.messages,
      outgoing: outgoing ?? this.outgoing,
      olderCursor: olderCursor == null ? this.olderCursor : olderCursor(),
      hasOlder: hasOlder ?? this.hasOlder,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      loadOlderFailed: loadOlderFailed ?? this.loadOlderFailed,
      peerIsTyping: peerIsTyping ?? this.peerIsTyping,
      localPhotos: localPhotos ?? this.localPhotos,
    );
  }
}

/// How sending a message turned out.
@immutable
sealed class SendOutcome {
  const SendOutcome();
}

final class Sent extends SendOutcome {
  const Sent();
}

/// Nothing to send, such as a message of only spaces.
final class NothingToSend extends SendOutcome {
  const NothingToSend();
}

/// The server's moderation suggests another look before sending. Nothing was
/// sent, and the user decides.
final class SendNeedsReview extends SendOutcome {
  const SendNeedsReview({required this.text, required this.check});

  final String text;
  final ModerationCheck check;
}

/// Sending needs a plan with more messages. The message waits, failed.
final class SendNeedsUpgrade extends SendOutcome {
  const SendNeedsUpgrade(this.paywall);

  final Paywall paywall;
}

/// The conversation is closed, so nothing more can be sent.
final class SendRefused extends SendOutcome {
  const SendRefused();
}

/// The message couldn't be sent, and waits to be tried again.
final class SendFailed extends SendOutcome {
  const SendFailed(this.message);

  final String message;
}

/// One conversation, by its id.
final chatControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ChatController, ChatThread, String>(ChatController.new);

class ChatController extends AsyncNotifier<ChatThread> {
  ChatController(this.conversationId);

  final String conversationId;

  /// While the user keeps typing, how often the other person is told again,
  /// so their indicator doesn't time out.
  static const typingRefresh = Duration(seconds: 3);

  /// How long after the last keystroke typing counts as stopped.
  static const typingIdle = Duration(seconds: 5);

  /// How long the other person shows as typing without hearing from them
  /// again. Their "stopped" can be lost on the way.
  static const peerTypingTimeout = Duration(seconds: 8);

  /// How long new messages wait before being marked read, so a burst is
  /// marked once.
  static const readDelay = Duration(milliseconds: 500);

  late RealtimeConnection _connection;

  Timer? _typingRefreshTimer;
  Timer? _typingIdleTimer;
  bool _isTyping = false;
  Timer? _peerTypingTimer;
  Timer? _readTimer;

  /// Sends go one at a time, so messages arrive in the order they were sent.
  Future<void> _sendQueue = Future.value();
  int _nextLocalId = 1;

  ChatRepository get _repository => ref.read(chatRepositoryProvider);

  @override
  Future<ChatThread> build() async {
    final repository = ref.watch(chatRepositoryProvider);
    final userId = ref.watch(chatUserIdProvider);
    if (userId == null) {
      // The account is still loading. This builds again once it has, so the
      // conversation waits rather than failing.
      return Completer<ChatThread>().future;
    }
    _connection = ref.watch(realtimeConnectionProvider);

    // Anything that arrives while the conversation loads is applied once it
    // has, so nothing slips between loading and listening.
    final early = <LiveUpdate>[];
    var loaded = false;
    final subscription = ref.watch(liveUpdatesProvider).stream.listen((update) {
      if (loaded) {
        _apply(update);
      } else {
        early.add(update);
      }
    });
    ref
      ..onDispose(() {
        unawaited(subscription.cancel());
        _stopTyping();
        _peerTypingTimer?.cancel();
        _readTimer?.cancel();
      })
      ..listen(realtimeStatusProvider, (previous, next) {
        if (next == RealtimeStatus.connected &&
            previous != RealtimeStatus.connected) {
          unawaited(_catchUp());
        }
      })
      ..listen(appInForegroundProvider, (_, foreground) {
        if (foreground) _scheduleRead();
      });

    final (conversation, page) = await _load(repository);
    var thread = ChatThread(
      userId: userId,
      conversation: conversation,
      messages: page.items,
      olderCursor: page.nextCursor,
      hasOlder: page.hasMore,
    );
    for (final update in early) {
      thread = _applyTo(thread, update);
    }
    loaded = true;
    if (thread.hasUnread) _scheduleRead();
    return thread;
  }

  /// Loads older messages, when there are more.
  Future<void> loadOlder() async {
    final thread = state.value;
    final cursor = thread?.olderCursor;
    if (thread == null ||
        !thread.hasOlder ||
        thread.isLoadingOlder ||
        cursor == null) {
      return;
    }

    _update((thread) {
      return thread.copyWith(isLoadingOlder: true, loadOlderFailed: false);
    });
    try {
      final page = await _repository.fetchMessages(
        conversationId,
        cursor: cursor,
      );
      if (!ref.mounted) return;
      _update((thread) {
        final shown = {for (final message in thread.messages) message.id};
        return thread.copyWith(
          messages: [
            ...thread.messages,
            for (final message in page.items)
              if (!shown.contains(message.id)) message,
          ],
          olderCursor: () => page.nextCursor,
          hasOlder: page.hasMore,
          isLoadingOlder: false,
        );
      });
    } on ApiException {
      if (!ref.mounted) return;
      _update((thread) {
        return thread.copyWith(isLoadingOlder: false, loadOlderFailed: true);
      });
    }
  }

  /// Sends [text], showing it straight away as on its way.
  ///
  /// Unless [reviewed], the server's moderation looks at it first, and a
  /// warning takes it back out so the user can decide. [reviewed] records
  /// that they chose to send it after one.
  Future<SendOutcome> send(String text, {bool reviewed = false}) {
    final body = text.trim();
    final thread = state.value;
    if (body.isEmpty || thread == null) {
      return Future.value(const NothingToSend());
    }
    if (!thread.conversation.isWritable) {
      return Future.value(const SendRefused());
    }

    _stopTyping();
    final outgoing = OutgoingMessage(
      localId: _newLocalId(),
      status: OutgoingStatus.sending,
      text: body,
      moderationOverridden: reviewed,
    );
    _update((thread) {
      return thread.copyWith(outgoing: [...thread.outgoing, outgoing]);
    });

    return _enqueue(() async {
      if (!ref.mounted) return const NothingToSend();
      if (!reviewed) {
        final check = await _check(body);
        if (check.shouldWarn) {
          _removeOutgoing(outgoing.localId);
          return SendNeedsReview(text: body, check: check);
        }
      }
      return _deliver(outgoing);
    });
  }

  /// Sends [photo], showing it straight away as on its way.
  Future<SendOutcome> sendPhoto(PreparedPhoto photo) {
    final thread = state.value;
    if (thread == null) return Future.value(const NothingToSend());
    if (!thread.conversation.isWritable) {
      return Future.value(const SendRefused());
    }

    final outgoing = OutgoingMessage(
      localId: _newLocalId(),
      status: OutgoingStatus.sending,
      photo: photo,
    );
    _update((thread) {
      return thread.copyWith(outgoing: [...thread.outgoing, outgoing]);
    });
    return _enqueue(() => _deliver(outgoing));
  }

  /// Tries a failed message again.
  Future<SendOutcome> retry(String localId) {
    final thread = state.value;
    final failed = thread?.outgoing
        .where((outgoing) => outgoing.localId == localId)
        .firstOrNull;
    if (thread == null ||
        failed == null ||
        failed.status != OutgoingStatus.failed) {
      return Future.value(const NothingToSend());
    }
    if (!thread.conversation.isWritable) {
      return Future.value(const SendRefused());
    }

    final retrying = failed.copyWith(
      status: OutgoingStatus.sending,
      failure: () => null,
    );
    _replaceOutgoing(retrying);
    return _enqueue(() => _deliver(retrying));
  }

  /// Gives up on a failed message.
  void discard(String localId) => _removeOutgoing(localId);

  /// Tells the other person the user is typing, or has stopped, from what's
  /// in the message box.
  void draftChanged(String text) {
    final thread = state.value;
    if (thread == null || !thread.conversation.isWritable) return;
    if (text.trim().isEmpty) {
      _stopTyping();
      return;
    }

    if (_typingRefreshTimer == null) {
      _connection.send(ClientEvents.typingStart, {
        'conversation_id': conversationId,
      });
      _isTyping = true;
      _typingRefreshTimer = Timer(typingRefresh, () {
        _typingRefreshTimer = null;
      });
    }
    _typingIdleTimer?.cancel();
    _typingIdleTimer = Timer(typingIdle, _stopTyping);
  }

  /// Turns notifications for this conversation off or on. Returns why it
  /// failed, or `null`.
  Future<String?> setMuted(bool muted) => _updateSettings(isMuted: muted);

  /// Moves this conversation to Archived, or back to Matches. Returns why it
  /// failed, or `null`.
  Future<String?> setArchived(bool archived) {
    return _updateSettings(isArchived: archived);
  }

  /// Ends the match for both people. Returns why it failed, or `null`.
  Future<String?> unmatch() {
    return _endMatch(
      (thread) => ref
          .read(matchesRepositoryProvider)
          .unmatch(thread.conversation.matchId),
    );
  }

  /// Blocks the other person, which also ends the match. Returns why it
  /// failed, or `null`.
  Future<String?> block() {
    return _endMatch(
      (thread) =>
          ref.read(safetyRepositoryProvider).block(thread.conversation.user.id),
    );
  }

  /// Gives the match more time, which reopens it if it had expired. Part of a
  /// paid plan.
  Future<ExtendOutcome> extend() async {
    final thread = state.value;
    if (thread == null) return const ExtendFailed('Please try again.');

    final keepAlive = ref.keepAlive();
    try {
      final match = await ref
          .read(matchesRepositoryProvider)
          .extend(thread.conversation.matchId);
      ref.invalidate(matchExpiredProvider(match.id));
      ref.read(liveUpdatesProvider).publish(MatchChanged(match));
      _update((thread) {
        return thread.copyWith(
          conversation: thread.conversation.copyWith(
            isWritable: match.isWritable,
            matchExpiresAt: match.expiresAt,
          ),
        );
      });
      return Extended(match);
    } on ApiException catch (error) {
      if (Paywall.fromError(error) case final paywall?) {
        return ExtendNeedsUpgrade(paywall);
      }
      return ExtendFailed(error.message);
    } finally {
      keepAlive.close();
    }
  }

  /// Closes the conversation after a report blocked the other person. The
  /// report has already told the lists.
  void reportedAndBlocked() {
    final thread = state.value;
    if (thread == null) return;
    _closed(thread, announce: false);
  }

  Future<(Conversation, CursorPage<ChatMessage>)> _load(
    ChatRepository repository,
  ) async {
    try {
      return await (
        repository.fetchConversation(conversationId),
        repository.fetchMessages(conversationId),
      ).wait;
    } on ParallelWaitError<
      (Conversation?, CursorPage<ChatMessage>?),
      (AsyncError?, AsyncError?)
    > catch (error) {
      // The first failure, as loading one after the other would report.
      final (conversationError, messagesError) = error.errors;
      final failure = (conversationError ?? messagesError)!;
      Error.throwWithStackTrace(failure.error, failure.stackTrace);
    }
  }

  /// Reads the conversation again after the live connection was away, since
  /// anything sent meanwhile never arrived.
  Future<void> _catchUp() async {
    if (state.value == null) return;

    final (Conversation, CursorPage<ChatMessage>) fresh;
    try {
      fresh = await _load(_repository);
    } on ApiException catch (error) {
      if (!ref.mounted) return;
      if (error case ApiErrorException(code: ApiErrorCode.notFound)) {
        _update((thread) {
          return thread.copyWith(
            conversation: thread.conversation.copyWith(isWritable: false),
          );
        });
      }
      return;
    }
    if (!ref.mounted) return;

    final (conversation, page) = fresh;
    _update((thread) {
      final newestShown = thread.messages.firstOrNull;
      final gap =
          newestShown != null &&
          page.hasMore &&
          page.items.every(
            (message) => message.createdAt.isAfter(newestShown.createdAt),
          );
      if (gap) {
        // More arrived than one page holds: start again from the newest.
        return thread.copyWith(
          conversation: conversation,
          messages: page.items,
          olderCursor: () => page.nextCursor,
          hasOlder: page.hasMore,
          loadOlderFailed: false,
        );
      }
      var messages = thread.messages;
      for (final message in page.items.reversed) {
        messages = _withMessage(messages, message);
      }
      return thread.copyWith(conversation: conversation, messages: messages);
    });
    _scheduleRead();
  }

  void _apply(LiveUpdate update) {
    final thread = state.value;
    if (thread == null) return;
    final next = _applyTo(thread, update);
    if (identical(next, thread)) return;
    state = AsyncData(next);

    switch (update) {
      case MessageReceived():
        _peerTypingTimer?.cancel();
        _scheduleRead();
      case TypingChanged(isTyping: true):
        _peerTypingTimer?.cancel();
        _peerTypingTimer = Timer(peerTypingTimeout, () {
          _update((thread) => thread.copyWith(peerIsTyping: false));
        });
      case TypingChanged(isTyping: false):
        _peerTypingTimer?.cancel();
      case _:
        break;
    }
  }

  /// [thread] with [update] applied, or [thread] itself when it isn't
  /// affected.
  ChatThread _applyTo(ChatThread thread, LiveUpdate update) {
    final peer = thread.conversation.user;
    switch (update) {
      case MessageReceived(:final message)
          when message.conversationId == conversationId:
        return thread.copyWith(
          messages: _withMessage(thread.messages, message),
          peerIsTyping: false,
        );

      case ConversationRead(
            conversationId: final id,
            :final readerId,
            :final readAt,
          )
          when id == conversationId && readerId != thread.userId:
        return thread.copyWith(
          messages: [
            for (final message in thread.messages)
              thread.isMine(message) &&
                      message.readAt == null &&
                      !message.createdAt.isAfter(readAt)
                  ? message.readAtTime(readAt)
                  : message,
          ],
        );

      case TypingChanged(
            conversationId: final id,
            :final userId,
            :final isTyping,
          )
          when id == conversationId && userId == peer.id:
        return thread.copyWith(peerIsTyping: isTyping);

      case PresenceChanged(:final userId, :final isOnline, :final lastActiveAt)
          when userId == peer.id:
        return thread.copyWith(
          conversation: thread.conversation.copyWith(
            user: peer.withPresence(
              isOnline: isOnline,
              lastActiveAt: lastActiveAt,
            ),
          ),
        );

      case _:
        return thread;
    }
  }

  void _scheduleRead() {
    _readTimer?.cancel();
    _readTimer = Timer(readDelay, () => unawaited(_markRead()));
  }

  Future<void> _markRead() async {
    final thread = state.value;
    // Only while the conversation is in front of the user.
    if (thread == null ||
        !thread.hasUnread ||
        !ref.read(appInForegroundProvider)) {
      return;
    }

    final updates = ref.read(liveUpdatesProvider);
    final now = ref.read(clockProvider)();
    try {
      await _repository.markRead(conversationId);
    } on ApiException {
      // Left unread; the next message or visit marks it.
      return;
    }
    updates.publish(
      ConversationActivity(conversationId: conversationId, unreadCount: 0),
    );
    if (!ref.mounted) return;
    _update((thread) {
      return thread.copyWith(
        conversation: thread.conversation.copyWith(unreadCount: 0),
        messages: [
          for (final message in thread.messages)
            !thread.isMine(message) && message.readAt == null
                ? message.readAtTime(now)
                : message,
        ],
      );
    });
  }

  Future<ModerationCheck> _check(String text) async {
    if (!ref.mounted) return ModerationCheck.clear;
    try {
      return await _repository.checkMessage(text);
    } on ApiException {
      // The check only advises, and the server checks every message sent
      // anyway, so a check that fails never holds a message back.
      return ModerationCheck.clear;
    }
  }

  /// Runs [send] once every send before it has finished, keeping this
  /// conversation alive until it has, even if the user leaves it.
  Future<SendOutcome> _enqueue(Future<SendOutcome> Function() send) {
    final keepAlive = ref.keepAlive();
    final result = _sendQueue.then((_) => send()).whenComplete(keepAlive.close);
    _sendQueue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<SendOutcome> _deliver(OutgoingMessage outgoing) async {
    // Only when the whole app is closing, which takes the message with it.
    if (!ref.mounted) return const NothingToSend();
    final repository = _repository;
    final updates = ref.read(liveUpdatesProvider);
    // Kept up to date, so a failure doesn't forget a finished upload.
    var current = outgoing;
    try {
      final ChatMessage message;
      if (outgoing.photo case final photo?) {
        final uploadId =
            outgoing.uploadId ?? await repository.uploadPhoto(photo);
        current = outgoing.copyWith(uploadId: uploadId);
        _replaceOutgoing(current);
        message = await repository.sendPhoto(conversationId, uploadId);
      } else {
        message = await repository.sendText(
          conversationId,
          outgoing.text ?? '',
          moderationOverridden: outgoing.moderationOverridden,
        );
      }

      _update((thread) {
        return thread.copyWith(
          outgoing: [
            for (final each in thread.outgoing)
              if (each.localId != outgoing.localId) each,
          ],
          messages: _withMessage(thread.messages, message),
          localPhotos: switch (outgoing.photo) {
            final photo? => {...thread.localPhotos, message.id: photo},
            null => null,
          },
        );
      });
      updates.publish(
        ConversationActivity(
          conversationId: conversationId,
          lastMessageAt: message.createdAt,
          lastMessagePreview: message.preview,
        ),
      );
      return const Sent();
    } on ApiException catch (error) {
      if (Paywall.fromError(error) case final paywall?) {
        _fail(current, switch (paywall) {
          DailyLimitReached() => "You've reached today's message limit.",
          PremiumFeature() => error.message,
        });
        return SendNeedsUpgrade(paywall);
      }
      if (error case ApiErrorException(
        code: ApiErrorCode.forbidden,
        details: {'is_writable': false},
      )) {
        // Closed by expiry or by the other person. The match may well still
        // be listed, so only this conversation changes.
        _removeOutgoing(outgoing.localId);
        if (state.value case final thread?) _closed(thread, announce: false);
        return const SendRefused();
      }
      _fail(current, error.message);
      return SendFailed(error.message);
    }
  }

  Future<String?> _updateSettings({bool? isArchived, bool? isMuted}) async {
    final keepAlive = ref.keepAlive();
    try {
      final conversation = await _repository.updateConversation(
        conversationId,
        isArchived: isArchived,
        isMuted: isMuted,
      );
      _update((thread) => thread.copyWith(conversation: conversation));
      if (isArchived != null) {
        ref
            .read(liveUpdatesProvider)
            .publish(
              ConversationActivity(
                conversationId: conversationId,
                isArchived: conversation.isArchived,
              ),
            );
      }
      return null;
    } on ApiException catch (error) {
      return error.message;
    } finally {
      keepAlive.close();
    }
  }

  Future<String?> _endMatch(
    Future<void> Function(ChatThread thread) end,
  ) async {
    final thread = state.value;
    if (thread == null) return null;

    // Kept alive until the lists have heard, even if the chat closes first.
    final keepAlive = ref.keepAlive();
    try {
      try {
        await end(thread);
      } on ApiErrorException catch (error) {
        // Already gone is what the user wanted.
        if (error.code != ApiErrorCode.notFound) rethrow;
      }
      _closed(thread);
      return null;
    } on ApiException catch (error) {
      return error.message;
    } finally {
      keepAlive.close();
    }
  }

  /// Closes the conversation, dropping anything still waiting to send. When
  /// [announce], its match ended on this device, and the lists showing it are
  /// told.
  void _closed(ChatThread thread, {bool announce = true}) {
    _stopTyping();
    if (!ref.mounted) return;
    if (announce) {
      ref
          .read(liveUpdatesProvider)
          .publish(MatchEnded(thread.conversation.matchId));
    }
    _update((thread) {
      return thread.copyWith(
        conversation: thread.conversation.copyWith(isWritable: false),
        outgoing: const [],
      );
    });
  }

  void _stopTyping() {
    _typingIdleTimer?.cancel();
    _typingIdleTimer = null;
    _typingRefreshTimer?.cancel();
    _typingRefreshTimer = null;
    if (!_isTyping) return;
    _isTyping = false;
    _connection.send(ClientEvents.typingStop, {
      'conversation_id': conversationId,
    });
  }

  String _newLocalId() => 'local-${_nextLocalId++}';

  void _fail(OutgoingMessage outgoing, String reason) {
    _replaceOutgoing(
      outgoing.copyWith(status: OutgoingStatus.failed, failure: () => reason),
    );
  }

  void _replaceOutgoing(OutgoingMessage replacement) {
    _update((thread) {
      return thread.copyWith(
        outgoing: [
          for (final each in thread.outgoing)
            each.localId == replacement.localId ? replacement : each,
        ],
      );
    });
  }

  void _removeOutgoing(String localId) {
    _update((thread) {
      return thread.copyWith(
        outgoing: [
          for (final each in thread.outgoing)
            if (each.localId != localId) each,
        ],
      );
    });
  }

  void _update(ChatThread Function(ChatThread thread) change) {
    if (!ref.mounted) return;
    if (state.value case final thread?) state = AsyncData(change(thread));
  }

  /// [messages] with [message] in its place by time, replacing any earlier
  /// copy of it.
  static List<ChatMessage> _withMessage(
    List<ChatMessage> messages,
    ChatMessage message,
  ) {
    final others = [
      for (final each in messages)
        if (each.id != message.id) each,
    ];
    var index = others.indexWhere(
      (each) => !each.createdAt.isAfter(message.createdAt),
    );
    if (index < 0) index = others.length;
    return [...others.take(index), message, ...others.skip(index)];
  }
}

/// Whether a match has expired, which extending it undoes. `false` when it
/// ended some other way, or when that couldn't be found out.
final matchExpiredProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  matchId,
) async {
  try {
    final match = await ref
        .watch(matchesRepositoryProvider)
        .fetchMatch(matchId);
    return match.isExpired;
  } on ApiException {
    return false;
  }
});
