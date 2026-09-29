import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/kinvo_colors.dart';

/// What the user chose after being asked to look at a message again.
enum ReviewChoice { edit, sendAnyway }

/// Shows [text] with what moderation found in it, and asks whether to change
/// it or send it as it is. Returns `null` when dismissed, which is the same as
/// editing.
Future<ReviewChoice?> showReviewMessageDialog(
  BuildContext context, {
  required String text,
  required List<String> warnings,
}) {
  return showDialog<ReviewChoice>(
    context: context,
    builder: (_) => ReviewMessageDialog(text: text, warnings: warnings),
  );
}

class ReviewMessageDialog extends StatelessWidget {
  const ReviewMessageDialog({
    required this.text,
    required this.warnings,
    super.key,
  });

  final String text;
  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final shown = warnings.isEmpty
        ? const ['This message could put you at risk.']
        : warnings;

    return Dialog(
      backgroundColor: context.colors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Review before you send',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kinvo spotted something that could put you at risk.',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.45,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: context.colors.textMuted,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: context.colors.dangerSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  text,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colors.dangerStrong,
                  ),
                ),
              ),
              for (final warning in shown) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceSoft.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    warning,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(ReviewChoice.edit),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: context.colors.divider),
                        shape: const StadiumBorder(),
                        foregroundColor: context.colors.textPrimary,
                        textStyle: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Edit message'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.of(context).pop(ReviewChoice.sendAnyway),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.colors.purple,
                        foregroundColor: context.colors.onAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Send anyway'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
