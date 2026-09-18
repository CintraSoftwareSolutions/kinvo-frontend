import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/media/photo_processing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/chat_message.dart';
import '../controllers/chat_controller.dart';

/// A conversation's messages, newest at the bottom, reading further back as
/// the user scrolls up.
class ChatTimeline extends StatelessWidget {
  const ChatTimeline({
    required this.thread,
    required this.now,
    required this.scrollController,
    required this.onLoadOlder,
    required this.onOutgoingTap,
    required this.onQuickReply,
    super.key,
  });

  final ChatThread thread;
  final DateTime now;
  final ScrollController scrollController;
  final VoidCallback onLoadOlder;
  final ValueChanged<OutgoingMessage> onOutgoingTap;

  /// Fills the message box, for a conversation with nothing in it yet.
  final ValueChanged<String> onQuickReply;

  @override
  Widget build(BuildContext context) {
    final entries = _entriesOf(thread);
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // The list runs bottom to top, so what's "after" is older.
        if (notification.metrics.extentAfter < 600) onLoadOlder();
        return false;
      },
      child: ListView.builder(
        controller: scrollController,
        reverse: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          return switch (entries[index]) {
            _MessageEntry(:final message, :final status) => _MessageRow(
              key: ValueKey(message.id),
              message: message,
              mine: thread.isMine(message),
              status: status,
              localPhoto: thread.localPhotos[message.id],
            ),
            _OutgoingEntry(:final outgoing) => _OutgoingRow(
              key: ValueKey(outgoing.localId),
              outgoing: outgoing,
              onTap: outgoing.status == OutgoingStatus.failed
                  ? () => onOutgoingTap(outgoing)
                  : null,
            ),
            _DayEntry(:final day) => _DaySeparator(day: day, now: now),
            _OlderEntry() => _OlderMessages(
              isLoading: thread.isLoadingOlder,
              failed: thread.loadOlderFailed,
              onRetry: onLoadOlder,
            ),
            _StartEntry() => _ConversationStart(
              name: thread.conversation.user.displayName,
              isEmpty: thread.messages.isEmpty && thread.outgoing.isEmpty,
              canReply: thread.conversation.isWritable,
              onQuickReply: onQuickReply,
            ),
          };
        },
      ),
    );
  }

  /// Everything shown, bottom first: messages on their way, then sent ones
  /// with a separator where the day changes, then the start of the
  /// conversation or a way further back.
  static List<_Entry> _entriesOf(ChatThread thread) {
    final messages = thread.messages;
    final newest = messages.firstOrNull;
    final entries = <_Entry>[
      for (final outgoing in thread.outgoing.reversed) _OutgoingEntry(outgoing),
    ];

    for (final (index, message) in messages.indexed) {
      final String? status;
      if (identical(message, newest) &&
          thread.isMine(message) &&
          thread.outgoing.isEmpty) {
        status = message.readAt == null ? 'Sent' : 'Read';
      } else {
        status = null;
      }
      entries.add(_MessageEntry(message, status));

      final older = index + 1 < messages.length ? messages[index + 1] : null;
      final startsDay = older == null
          ? !thread.hasOlder
          : !_sameDay(older.createdAt, message.createdAt);
      if (startsDay) entries.add(_DayEntry(message.createdAt));
    }

    entries.add(thread.hasOlder ? const _OlderEntry() : const _StartEntry());
    return entries;
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final left = a.toLocal();
    final right = b.toLocal();
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}

sealed class _Entry {
  const _Entry();
}

final class _MessageEntry extends _Entry {
  const _MessageEntry(this.message, this.status);

  final ChatMessage message;

  /// "Sent" or "Read", under the user's latest message.
  final String? status;
}

final class _OutgoingEntry extends _Entry {
  const _OutgoingEntry(this.outgoing);

  final OutgoingMessage outgoing;
}

final class _DayEntry extends _Entry {
  const _DayEntry(this.day);

  final DateTime day;
}

final class _OlderEntry extends _Entry {
  const _OlderEntry();
}

final class _StartEntry extends _Entry {
  const _StartEntry();
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.mine,
    required this.status,
    required this.localPhoto,
    super.key,
  });

  final ChatMessage message;
  final bool mine;
  final String? status;
  final PreparedPhoto? localPhoto;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(message.createdAt.toLocal()),
    );
    final footer = [time, ?status].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          switch (message.kind) {
            MessageKind.image => _PhotoBubble(
              mine: mine,
              localPhoto: localPhoto,
              url: message.mediaUrl,
            ),
            MessageKind.text => _TextBubble(
              mine: mine,
              text: message.body ?? '',
            ),
            MessageKind.video => _NoticeBubble(
              mine: mine,
              icon: Icons.videocam_outlined,
              text: 'Video',
            ),
            MessageKind.voiceNote => _NoticeBubble(
              mine: mine,
              icon: Icons.mic_none_rounded,
              text: ['Voice note', ?_duration(message.duration)].join(' · '),
            ),
            MessageKind.venueCard => _NoticeBubble(
              mine: mine,
              icon: Icons.place_outlined,
              text: 'Suggested a place',
            ),
            MessageKind.unsupported => _NoticeBubble(
              mine: mine,
              icon: Icons.update_rounded,
              text: 'Update Kinvo to see this message',
            ),
          },
          if (message.isFlagged && !mine) const _FlaggedWarning(),
          const SizedBox(height: 4),
          Text(
            footer,
            style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  static String? _duration(Duration? duration) {
    if (duration == null) return null;
    final seconds = duration.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

class _OutgoingRow extends StatelessWidget {
  const _OutgoingRow({required this.outgoing, required this.onTap, super.key});

  final OutgoingMessage outgoing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final failed = outgoing.status == OutgoingStatus.failed;
    final photo = outgoing.photo;
    final bubble = photo == null
        ? _TextBubble(mine: true, text: outgoing.text ?? '', dimmed: !failed)
        : _PhotoBubble(mine: true, localPhoto: photo, url: null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: failed,
        hint: failed ? 'Try again or delete' : null,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Opacity(opacity: failed ? 0.6 : 1, child: bubble),
              const SizedBox(height: 4),
              if (failed)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 13,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${outgoing.failure ?? 'Not sent'}. Tap to try again.',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                )
              else
                const Text(
                  'Sending…',
                  style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextBubble extends StatelessWidget {
  const _TextBubble({
    required this.mine,
    required this.text,
    this.dimmed = false,
  });

  final bool mine;
  final String text;

  /// Lighter while the message is on its way.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return _BubbleFrame(
      mine: mine,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      color: mine
          ? AppColors.purple.withValues(alpha: dimmed ? 0.75 : 1)
          : Colors.white,
      child: GestureDetector(
        onLongPress: () => _copy(context),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: mine ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Message copied.')));
  }
}

class _NoticeBubble extends StatelessWidget {
  const _NoticeBubble({
    required this.mine,
    required this.icon,
    required this.text,
  });

  final bool mine;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = mine ? Colors.white : AppColors.textPrimary;
    return _BubbleFrame(
      mine: mine,
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      color: mine ? AppColors.purple : Colors.white,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoBubble extends StatelessWidget {
  const _PhotoBubble({
    required this.mine,
    required this.localPhoto,
    required this.url,
  });

  static const _width = 220.0;

  final bool mine;
  final PreparedPhoto? localPhoto;
  final Uri? url;

  @override
  Widget build(BuildContext context) {
    final localPhoto = this.localPhoto;
    final url = this.url;
    final height = localPhoto == null
        ? 260.0
        : (_width * localPhoto.height / localPhoto.width).clamp(140.0, 320.0);

    final Widget image;
    if (localPhoto != null) {
      image = Image.memory(localPhoto.bytes, fit: BoxFit.cover);
    } else if (url != null) {
      image = Image.network(
        url.toString(),
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          return progress == null ? child : const _PhotoPlaceholder();
        },
        // The link may have expired; reopening the conversation gets a new
        // one.
        errorBuilder: (_, _, _) => const _PhotoPlaceholder(failed: true),
      );
    } else {
      image = const _PhotoPlaceholder(failed: true);
    }

    return Semantics(
      image: true,
      label: mine ? 'Photo you sent' : 'Photo',
      child: GestureDetector(
        onTap: localPhoto == null && url == null
            ? null
            : () => _openViewer(context, image),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(width: _width, height: height, child: image),
        ),
      ),
    );
  }

  static Future<void> _openViewer(BuildContext context, Widget image) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (dialogContext) => GestureDetector(
        onTap: () => Navigator.of(dialogContext).pop(),
        child: SafeArea(
          child: Center(
            child: InteractiveViewer(
              maxScale: 4,
              child: switch (image) {
                Image(:final image) => Image(image: image, fit: BoxFit.contain),
                _ => image,
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({this.failed = false});

  final bool failed;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceSoft,
      child: Center(
        child: failed
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
                  SizedBox(height: 6),
                  Text(
                    "Photo can't be shown",
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              )
            : const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
      ),
    );
  }
}

class _BubbleFrame extends StatelessWidget {
  const _BubbleFrame({
    required this.mine,
    required this.padding,
    required this.color,
    required this.child,
  });

  final bool mine;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.75,
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 6),
            bottomRight: Radius.circular(mine ? 6 : 18),
          ),
          border: mine ? null : Border.all(color: AppColors.divider),
          boxShadow: mine
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x0A0C132A),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: child,
      ),
    );
  }
}

class _FlaggedWarning extends StatelessWidget {
  const _FlaggedWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.75,
      ),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 14, color: AppColors.danger),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'Be careful: never send money or personal details to someone '
              "you haven't met.",
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: Color(0xFFB91C1C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.day, required this.now});

  final DateTime day;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final local = day.toLocal();
    final today = now.toLocal();
    final dayOnly = DateTime(local.year, local.month, local.day);
    final todayOnly = DateTime(today.year, today.month, today.day);
    final daysAgo = todayOnly.difference(dayOnly).inDays;
    final label = switch (daysAgo) {
      0 => 'Today',
      1 => 'Yesterday',
      _ => MaterialLocalizations.of(context).formatMediumDate(local),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.divider),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _OlderMessages extends StatelessWidget {
  const _OlderMessages({
    required this.isLoading,
    required this.failed,
    required this.onRetry,
  });

  final bool isLoading;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return Center(
        child: TextButton(
          onPressed: onRetry,
          child: const Text("Earlier messages didn't load. Try again"),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(12),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}

class _ConversationStart extends StatelessWidget {
  const _ConversationStart({
    required this.name,
    required this.isEmpty,
    required this.canReply,
    required this.onQuickReply,
  });

  final String name;
  final bool isEmpty;
  final bool canReply;
  final ValueChanged<String> onQuickReply;

  @override
  Widget build(BuildContext context) {
    final replies = [
      'Hi $name! 👋',
      "How's your week going?",
      'What are you up to this weekend?',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A0C132A),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: SvgPicture.asset(
                    AppAssets.shield,
                    width: 16,
                    height: 16,
                    colorFilter: const ColorFilter.mode(
                      AppColors.purple,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safety tools are one tap away',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Report or block from the menu at the top. Never send '
                        "money to someone you haven't met.",
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isEmpty && canReply) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final reply in replies)
                  ActionChip(
                    label: Text(reply),
                    onPressed: () => onQuickReply(reply),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.divider),
                    shape: const StadiumBorder(),
                    labelStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
