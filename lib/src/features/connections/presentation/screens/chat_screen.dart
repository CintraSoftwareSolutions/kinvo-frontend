import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/chat_message.dart';
import '../../domain/connection.dart';
import '../controllers/chat_controller.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.connection, super.key});

  final Connection connection;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late final TextEditingController _draftController;
  bool _voiceMode = false;

  @override
  void initState() {
    super.initState();
    _draftController = TextEditingController();
  }

  @override
  void dispose() {
    _draftController.dispose();
    super.dispose();
  }

  void _handleSend() {
    final controller = ref.read(chatControllerProvider.notifier);
    final text = _draftController.text.trim();
    if (text.isEmpty) return;
    if (controller.isRisky(text)) {
      Navigator.of(context).pushNamed(
        AppRoutes.chatReview,
        arguments: text,
      );
      return;
    }
    controller.send(text);
    _draftController.clear();
  }

  void _quickReply(String text) {
    _draftController.text = text;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    final c = widget.connection;

    return Column(
      children: [
        _ChatHeader(connection: c),
        const Divider(height: 1, color: Color(0xFFEDEFF5)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            children: [
              _SafetyBanner(),
              const SizedBox(height: 14),
              _QuickReplies(onTap: _quickReply),
              const SizedBox(height: 14),
              for (final m in state.messages) ...[
                _MessageBubble(message: m),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        _Composer(
          controller: _draftController,
          voiceMode: _voiceMode,
          onMicTap: () => setState(() => _voiceMode = !_voiceMode),
          onAttachTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Attach image (front-end demo)')),
            );
          },
          onSend: _handleSend,
        ),
      ],
    );
  }
}

class _CircleHeaderButton extends StatelessWidget {
  const _CircleHeaderButton({
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: AppColors.surfaceSoft,
          shape: BoxShape.circle,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.connection});

  final Connection connection;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          _CircleHeaderButton(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connection.name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${connection.mode} mode',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '|',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Active 2m ago',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _CircleHeaderButton(
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.videoCall,
              arguments: connection,
            ),
            child: SvgPicture.asset(
              AppAssets.video,
              width: 18,
              height: 18,
              colorFilter: const ColorFilter.mode(
                AppColors.textPrimary,
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _CircleHeaderButton(
            onTap: () => _showOptions(context, connection),
            child: const Icon(
              Icons.more_vert_rounded,
              size: 20,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showOptions(BuildContext context, Connection c) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _SheetRow(
                icon: Icons.flag_outlined,
                label: 'Report ${c.name}',
                onTap: () {
                  Navigator.of(sheet).pop();
                  Navigator.of(context).pushNamed(
                    AppRoutes.report,
                    arguments: c,
                  );
                },
              ),
              _SheetRow(
                icon: Icons.archive_outlined,
                label: 'Archive',
                onTap: () => Navigator.of(sheet).pop(),
              ),
              _SheetRow(
                icon: Icons.block_outlined,
                label: 'Block',
                tone: const Color(0xFFEF4444),
                onTap: () => Navigator.of(sheet).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = AppColors.textPrimary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: tone),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
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
                  'Share plans, open venue suggestions, or report from the header menu.',
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
    );
  }
}

class _QuickReplies extends StatelessWidget {
  const _QuickReplies({required this.onTap});

  final ValueChanged<String> onTap;

  static const _replies = [
    'Coffee this weekend?',
    'Plan something',
    'Send venue',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final r in _replies)
          GestureDetector(
            onTap: () => onTap(r),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0C132A),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                r,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isMe = message.sender == ChatMessageSender.me;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: isMe ? AppColors.purple : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isMe ? null : Border.all(color: AppColors.divider),
            boxShadow: isMe
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x0A0C132A),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.text,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: isMe ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isMe && message.delivered ? 'Delivered' : message.timeAgo,
                style: TextStyle(
                  fontSize: 10.5,
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.75)
                      : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.voiceMode,
    required this.onMicTap,
    required this.onAttachTap,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool voiceMode;
  final VoidCallback onMicTap;
  final VoidCallback onAttachTap;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0C132A),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (voiceMode) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE4E8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: const [
                    Text(
                      'Voice note mode is active',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEF4458),
                      ),
                    ),
                    Spacer(),
                    Text(
                      'Tap the mic again to cancel',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                GestureDetector(
                  onTap: onAttachTap,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        AppAssets.image,
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          AppColors.textSecondary,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                              hintText: 'Type a message...',
                              border: InputBorder.none,
                              isDense: true,
                              hintStyle: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13.5,
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: AppColors.textPrimary,
                            ),
                            onSubmitted: (_) => onSend(),
                          ),
                        ),
                        GestureDetector(
                          onTap: onMicTap,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.mic_none_rounded,
                              size: 20,
                              color: voiceMode
                                  ? const Color(0xFFEF4458)
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onSend,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.purple,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        AppAssets.send,
                        width: 18,
                        height: 18,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
