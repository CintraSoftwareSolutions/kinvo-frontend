import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/flow_widgets.dart';
import '../controllers/chat_controller.dart';

/// Takes the place of the message box once a conversation can't be replied
/// to. Offers to extend the match when it's expiry that closed it; the other
/// reasons, such as being blocked, are never told apart.
class ClosedConversationPanel extends ConsumerWidget {
  const ClosedConversationPanel({
    required this.matchId,
    required this.isExtending,
    required this.onExtend,
    super.key,
  });

  final String matchId;
  final bool isExtending;
  final VoidCallback onExtend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expired = ref.watch(matchExpiredProvider(matchId)).value ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      expired
                          ? 'This match has expired. Extend it to keep '
                                'talking.'
                          : "You can't reply to this conversation any more.",
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (expired) ...[
              const SizedBox(height: 12),
              PrimaryActionButton(
                label: 'Extend match',
                loading: isExtending,
                borderRadius: 999,
                onPressed: onExtend,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
