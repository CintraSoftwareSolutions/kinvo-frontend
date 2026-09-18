import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/time/clock.dart';
import '../../../discovery/domain/discovery_formatting.dart';
import '../../../discovery/presentation/controllers/discovery_modes_controller.dart';
import '../../../modes/presentation/mode_presentation.dart';
import '../../../profile/presentation/widgets/person_photo.dart';
import '../../domain/conversation.dart';

/// The top of a conversation: who it's with, what they're doing, and the
/// conversation's menu.
class ChatHeader extends ConsumerWidget {
  const ChatHeader({
    required this.conversation,
    required this.peerIsTyping,
    required this.onBack,
    required this.onOpenProfile,
    required this.onOpenMenu,
    this.onVideoCall,
    super.key,
  });

  final Conversation conversation;
  final bool peerIsTyping;
  final VoidCallback onBack;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenMenu;

  /// Shown only where calling works.
  final VoidCallback? onVideoCall;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = conversation.user;
    final now = ref.watch(clockProvider)();
    final modeLabel = ref.watch(modeLabelProvider(conversation.mode));
    final status = peerIsTyping ? 'typing…' : activityLabel(user, now: now);
    final onVideoCall = this.onVideoCall;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          HeaderCircleButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onTap: onBack,
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              button: true,
              label: [
                user.displayName,
                modeLabel,
                ?status,
                'View profile',
              ].join(', '),
              excludeSemantics: true,
              child: GestureDetector(
                onTap: onOpenProfile,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    _Avatar(conversation: conversation),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                              if (user.isVerified) ...[
                                const SizedBox(width: 5),
                                SvgPicture.asset(
                                  AppAssets.shield,
                                  width: 13,
                                  height: 13,
                                  colorFilter: const ColorFilter.mode(
                                    AppColors.blue,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            [modeLabel, ?status].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: peerIsTyping
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: peerIsTyping
                                  ? AppColors.purple
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onVideoCall != null) ...[
            const SizedBox(width: 8),
            HeaderCircleButton(
              tooltip: 'Video call',
              onTap: onVideoCall,
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
          ],
          const SizedBox(width: 8),
          HeaderCircleButton(
            tooltip: 'Conversation options',
            onTap: onOpenMenu,
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
}

/// A round header button with a label for screen readers.
class HeaderCircleButton extends StatelessWidget {
  const HeaderCircleButton({
    required this.tooltip,
    required this.onTap,
    required this.child,
    super.key,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: GestureDetector(
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
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final user = conversation.user;
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: SizedBox(
              width: 40,
              height: 40,
              child: PersonPhoto(
                url: user.photoUrl,
                name: user.displayName,
                color: modeColors(conversation.mode).primary,
                initialSize: 17,
              ),
            ),
          ),
          if (user.isOnline)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
