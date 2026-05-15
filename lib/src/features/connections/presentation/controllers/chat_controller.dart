import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/chat_message.dart';

class ChatState {
  const ChatState({required this.messages, required this.draft});
  final List<ChatMessage> messages;
  final String draft;

  ChatState copyWith({List<ChatMessage>? messages, String? draft}) {
    return ChatState(
      messages: messages ?? this.messages,
      draft: draft ?? this.draft,
    );
  }
}

class ChatController extends Notifier<ChatState> {
  @override
  ChatState build() {
    return ChatState(messages: List.of(SampleChat.messages), draft: '');
  }

  bool isRisky(String text) {
    final lower = text.toLowerCase();
    const flags = [
      'money',
      'cash',
      'secret',
      'payment',
      'venmo',
      'crypto',
      'wire',
      'send me',
      'leave the app',
    ];
    return flags.any(lower.contains);
  }

  void setDraft(String value) => state = state.copyWith(draft: value);

  void send(String text) {
    if (text.trim().isEmpty) return;
    final next = [
      ...state.messages,
      ChatMessage(
        id: 'm${state.messages.length + 1}',
        sender: ChatMessageSender.me,
        text: text.trim(),
        timeAgo: 'now',
        delivered: true,
      ),
    ];
    state = state.copyWith(messages: next, draft: '');
  }
}

final chatControllerProvider =
    NotifierProvider<ChatController, ChatState>(ChatController.new);
