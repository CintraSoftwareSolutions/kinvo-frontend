import '../../../core/assets/app_assets.dart';

class Connection {
  const Connection({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.timeAgo,
    required this.avatar,
    required this.unread,
    this.online = false,
    this.mode = 'Dating',
  });

  final String id;
  final String name;
  final String lastMessage;
  final String timeAgo;
  final String avatar;
  final int unread;
  final bool online;
  final String mode;
}

abstract final class SampleConnections {
  static const matches = <Connection>[
    Connection(
      id: 'sarah',
      name: 'Sarah',
      lastMessage: 'Hey! Would love to check out that new...',
      timeAgo: '2m',
      avatar: AppAssets.avatarSarah,
      unread: 2,
      online: true,
      mode: 'Dating',
    ),
    Connection(
      id: 'marcus',
      name: 'Marcus',
      lastMessage: 'The AI conference next week looks inter...',
      timeAgo: '1h',
      avatar: AppAssets.avatarMarcus,
      unread: 0,
      online: true,
      mode: 'Networking',
    ),
    Connection(
      id: 'emma',
      name: 'Emma',
      lastMessage: 'Should we meet tomorrow to work on t...',
      timeAgo: '3h',
      avatar: AppAssets.avatarEmma,
      unread: 1,
      online: true,
      mode: 'Study Buddy',
    ),
  ];
}
