import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Something the user can do with a conversation from its menu.
enum ChatMenuAction {
  viewProfile,
  suggestPlan,
  mute,
  unmute,
  archive,
  unarchive,
  extend,
  report,
  unmatch,
  block,
}

/// Offers [actions] for the conversation with [name]. Returns the one chosen,
/// or `null` when dismissed.
Future<ChatMenuAction?> showChatMenuSheet(
  BuildContext context, {
  required String name,
  required List<ChatMenuAction> actions,
}) {
  return showModalBottomSheet<ChatMenuAction>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheet) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
            const SizedBox(height: 12),
            for (final action in actions)
              _MenuRow(
                action: action,
                name: name,
                onTap: () => Navigator.of(sheet).pop(action),
              ),
          ],
        ),
      ),
    ),
  );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.action,
    required this.name,
    required this.onTap,
  });

  final ChatMenuAction action;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, label, danger) = switch (action) {
      ChatMenuAction.viewProfile => (
        Icons.person_outline_rounded,
        'View profile',
        false,
      ),
      ChatMenuAction.suggestPlan => (
        Icons.event_outlined,
        'Suggest a plan',
        false,
      ),
      ChatMenuAction.mute => (
        Icons.notifications_off_outlined,
        'Mute notifications',
        false,
      ),
      ChatMenuAction.unmute => (
        Icons.notifications_active_outlined,
        'Unmute notifications',
        false,
      ),
      ChatMenuAction.archive => (Icons.archive_outlined, 'Archive', false),
      ChatMenuAction.unarchive => (
        Icons.unarchive_outlined,
        'Move back to Matches',
        false,
      ),
      ChatMenuAction.extend => (Icons.update_rounded, 'Extend match', false),
      ChatMenuAction.report => (Icons.flag_outlined, 'Report $name', true),
      ChatMenuAction.unmatch => (Icons.heart_broken_outlined, 'Unmatch', true),
      ChatMenuAction.block => (Icons.block_rounded, 'Block $name', true),
    };
    final color = danger ? AppColors.danger : AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 21, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
