import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/deck_stats.dart';
import '../../domain/swipe.dart';

/// The card above the deck: the mode, what's left of today's likes, and the
/// boost.
class DeckSummaryCard extends StatelessWidget {
  const DeckSummaryCard({
    required this.modeLabel,
    required this.modeColor,
    required this.modeSoftColor,
    required this.allowance,
    required this.boost,
    required this.isStartingBoost,
    required this.onBoost,
    required this.now,
    super.key,
  });

  final String modeLabel;
  final Color modeColor;
  final Color modeSoftColor;

  /// What's left of today's likes, or `null` while it's not known yet.
  final SwipeAllowance? allowance;

  /// The boost running in this mode, if any.
  final ActiveBoost? boost;

  final bool isStartingBoost;
  final VoidCallback onBoost;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final allowance = this.allowance;
    final boost = this.boost;
    final allowanceText = switch (allowance) {
      null => ' ',
      SwipeAllowance(isUnlimited: true) => 'Unlimited likes',
      SwipeAllowance(remaining: 1) => '1 like left today',
      SwipeAllowance(:final remaining) => '$remaining likes left today',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0C132A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DISCOVER',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  modeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  allowanceText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (boost != null && boost.isActiveAt(now))
            _BoostRunning(
              until: _time(context, boost.endsAt),
              color: modeColor,
              softColor: modeSoftColor,
            )
          else
            _BoostButton(
              color: modeColor,
              softColor: modeSoftColor,
              loading: isStartingBoost,
              onTap: onBoost,
            ),
        ],
      ),
    );
  }

  static String _time(BuildContext context, DateTime at) {
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(at.toLocal()),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
  }
}

class _BoostButton extends StatelessWidget {
  const _BoostButton({
    required this.color,
    required this.softColor,
    required this.loading,
    required this.onTap,
  });

  final Color color;
  final Color softColor;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Boost',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: loading ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: softColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Icon(Icons.bolt_rounded, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                'Boost',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoostRunning extends StatelessWidget {
  const _BoostRunning({
    required this.until,
    required this.color,
    required this.softColor,
  });

  final String until;
  final Color color;
  final Color softColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: softColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt_rounded, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                'Boosted',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'until $until',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
