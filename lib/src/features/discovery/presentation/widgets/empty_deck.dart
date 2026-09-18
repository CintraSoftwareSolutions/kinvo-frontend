import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/deck_stats.dart';

/// What Discover shows once today's deck for a mode has run out.
class EmptyDeck extends StatelessWidget {
  const EmptyDeck({
    required this.modeLabel,
    required this.stats,
    required this.onRewind,
    required this.onAdjustFilters,
    required this.onRefresh,
    super.key,
  });

  final String modeLabel;

  /// Today's numbers, or `null` while they load or if they couldn't be read.
  final DeckStats? stats;

  final VoidCallback onRewind;
  final VoidCallback onAdjustFilters;

  /// Reads the deck again, for when someone new may have turned up.
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final stats = this.stats;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0C132A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.surfaceSoft,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgPicture.asset(
                AppAssets.searchOff,
                width: 32,
                height: 32,
                colorFilter: const ColorFilter.mode(
                  AppColors.textMuted,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "You're all caught up in $modeLabel",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'New people arrive every day. Widen your filters to see more '
              'now, or bring back the last person you passed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.55,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (stats != null) ...[
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'LIKED',
                    value: '${stats.liked + stats.superLiked}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(label: 'PASSED', value: '${stats.passed}'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(label: 'MATCHES', value: '${stats.matches}'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onAdjustFilters,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Adjust filters'),
            ),
          ),
          const SizedBox(height: 10),
          _OutlineButton(label: 'Undo last swipe', onTap: onRewind),
          const SizedBox(height: 8),
          _OutlineButton(label: 'Check for new people', onTap: onRefresh),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.divider),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
