import '../../../core/media/photo_processing.dart';
import '../../../core/network/api_error_code.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/cursor_page.dart';
import '../../../core/time/clock.dart';
import '../../discovery/data/demo_people.dart';
import '../../matches/data/demo_inbox.dart';
import '../domain/chat_message.dart';
import '../domain/conversation.dart';
import '../domain/moderation_check.dart';
import 'chat_repository.dart';

/// Chat for the demo: sample conversations with the demo's matches, kept in
/// memory alongside them in [DemoInbox].
final class DemoChatRepository implements ChatRepository {
  DemoChatRepository({required DemoInbox inbox, required Clock clock})
    : _inbox = inbox,
      _clock = clock {
    for (final match in inbox.matches) {
      _threads[match.id] = _sampleThread(match);
    }
  }

  /// The demo's stand-in for the user, as the sender of their messages.
  static const userId = 'demo-you';

  /// Words the demo's moderation warns about, standing in for the server's.
  static const _riskyWords = [
    'bank',
    'cash',
    'crypto',
    'gift card',
    'money',
    'payment',
    'send me',
    'transfer',
    'whatsapp',
  ];

  final DemoInbox _inbox;
  final Clock _clock;

  /// Each conversation's messages, newest first.
  final Map<String, List<ChatMessage>> _threads = {};

  int _nextId = 1;

  @override
  Future<Conversation> fetchConversation(String conversationId) async {
    return _conversationOf(_find(conversationId));
  }

  @override
  Future<CursorPage<ChatMessage>> fetchMessages(
    String conversationId, {
    String? cursor,
  }) async {
    final messages = _threads[_find(conversationId).id] ?? const [];
    return CursorPage(
      items: [...messages],
      nextCursor: null,
      hasMore: false,
      limit: messages.length,
    );
  }

  @override
  Future<ChatMessage> sendText(
    String conversationId,
    String text, {
    required bool moderationOverridden,
  }) async {
    return _add(conversationId, MessageKind.text, body: text);
  }

  @override
  Future<String> uploadPhoto(PreparedPhoto photo) async {
    return 'demo-upload-${_nextId++}';
  }

  @override
  Future<ChatMessage> sendPhoto(String conversationId, String uploadId) async {
    // The photo itself stays on the device, which shows it from there.
    return _add(conversationId, MessageKind.image);
  }

  @override
  Future<void> markRead(String conversationId) async {
    final match = _find(conversationId);
    final now = _clock();
    match.unreadCount = 0;
    _threads[match.id] = [
      for (final message in _threads[match.id] ?? const <ChatMessage>[])
        message.senderId != userId && message.readAt == null
            ? message.readAtTime(now)
            : message,
    ];
  }

  @override
  Future<Conversation> updateConversation(
    String conversationId, {
    bool? isArchived,
    bool? isMuted,
  }) async {
    final match = _find(conversationId);
    if (isArchived != null) match.isArchived = isArchived;
    if (isMuted != null) match.isMuted = isMuted;
    return _conversationOf(match);
  }

  @override
  Future<int> fetchUnreadCount() async {
    return _inbox.matches
        .where((match) => !match.isUnmatched)
        .fold<int>(0, (total, match) => total + match.unreadCount);
  }

  @override
  Future<ModerationCheck> checkMessage(String text) async {
    final lower = text.toLowerCase();
    if (!_riskyWords.any(lower.contains)) return ModerationCheck.clear;
    return const ModerationCheck(
      shouldWarn: true,
      warnings: [
        'This message mentions money or moving the chat elsewhere. Scammers '
            'often ask for both.',
      ],
    );
  }

  ChatMessage _add(String conversationId, MessageKind kind, {String? body}) {
    final match = _find(conversationId);
    final message = ChatMessage(
      id: 'demo-message-${_nextId++}',
      conversationId: match.id,
      senderId: userId,
      kind: kind,
      body: body,
      mediaUrl: null,
      duration: null,
      isFlagged: false,
      readAt: null,
      createdAt: _clock(),
    );
    _threads[match.id] = [message, ...?_threads[match.id]];
    // Sending leaves an archived conversation archived, as on the server.
    match
      ..lastMessagePreview = message.preview
      ..lastMessageAt = message.createdAt;
    return message;
  }

  Conversation _conversationOf(DemoMatchState match) {
    final person = demoPersonById(match.id);
    if (person == null) throw _notFound;
    final now = _clock();
    return Conversation(
      id: match.id,
      matchId: match.id,
      mode: match.mode,
      user: person.summaryAt(now),
      lastMessageAt: match.lastMessageAt,
      lastMessagePreview: match.lastMessagePreview,
      unreadCount: match.unreadCount,
      isArchived: match.isArchived,
      isMuted: match.isMuted,
      isWritable: match.expiresAt.isAfter(now),
      matchExpiresAt: match.expiresAt,
    );
  }

  DemoMatchState _find(String conversationId) {
    return _inbox.find(conversationId) ?? (throw _notFound);
  }

  /// A few messages leading up to the match's last one, ending with as many
  /// unread as the inbox says.
  List<ChatMessage> _sampleThread(DemoMatchState match) {
    final lines = switch (match.id) {
      'sarah' => const [
        (false, 'Hi! I saw you like hiking too.'),
        (true, 'I do! I did the Box Hill loop last weekend.'),
        (false, "No way, that's my favourite walk."),
      ],
      'marcus' => const [
        (true, 'Are you going to the AI meetup on Thursday?'),
        (false, "I can't make Thursday, sadly."),
      ],
      'emma' => const [
        (false, 'Did you finish the graphs problem set?'),
        (true, 'Almost. Question 4 is tough.'),
      ],
      _ => const <(bool, String)>[],
    };
    final all = [...lines, (false, match.lastMessagePreview)];
    final unread = match.unreadCount;

    return [
      for (final (index, (mine, body)) in all.indexed.toList().reversed)
        ChatMessage(
          id: 'demo-${match.id}-$index',
          conversationId: match.id,
          senderId: mine ? userId : match.id,
          kind: MessageKind.text,
          body: body,
          mediaUrl: null,
          duration: null,
          isFlagged: false,
          readAt: mine || index < all.length - unread
              ? match.lastMessageAt.subtract(const Duration(minutes: 1))
              : null,
          createdAt: match.lastMessageAt.subtract(
            Duration(minutes: (all.length - 1 - index) * 7),
          ),
        ),
    ];
  }

  static const _notFound = ApiErrorException(
    code: ApiErrorCode.notFound,
    message: 'We could not find that.',
    statusCode: 404,
  );
}
