enum ChatMessageSender { me, peer }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timeAgo,
    this.delivered = false,
  });

  final String id;
  final ChatMessageSender sender;
  final String text;
  final String timeAgo;
  final bool delivered;
}

abstract final class SampleChat {
  static const messages = <ChatMessage>[
    ChatMessage(
      id: 'm1',
      sender: ChatMessageSender.peer,
      text: 'Hey! Would love to check out that new coffee place downtown',
      timeAgo: '2m ago',
    ),
    ChatMessage(
      id: 'm2',
      sender: ChatMessageSender.me,
      text: "That sounds perfect! I've been wanting to try it too 😍",
      timeAgo: '2m ago',
      delivered: true,
    ),
    ChatMessage(
      id: 'm3',
      sender: ChatMessageSender.peer,
      text: 'How about this Saturday at 2pm?',
      timeAgo: '3m ago',
    ),
  ];
}
