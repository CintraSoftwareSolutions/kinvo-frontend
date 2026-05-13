import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/discover_mode.dart';
import '../controllers/home_controller.dart';

class EmptyDeckState extends StatelessWidget {
  const EmptyDeckState({
    required this.mode,
    required this.stats,
    required this.onReview,
    required this.onUndo,
    required this.onAdjustFilters,
    super.key,
  });

  final DiscoverMode mode;
  final DeckStats stats;
  final VoidCallback onReview;
  final VoidCallback onUndo;
  final VoidCallback onAdjustFilters;

  @override
  Widget build(BuildContext context) {
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
            "You're caught up in ${mode.label}",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              mode.emptyStateMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.55,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: _StatTile(label: 'LIKED', value: '${stats.liked}')),
              const SizedBox(width: 10),
              Expanded(child: _StatTile(label: 'PASSED', value: '${stats.passed}')),
              const SizedBox(width: 10),
              Expanded(child: _StatTile(label: 'BOOSTS', value: '${stats.boosts}')),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onReview,
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
              child: const Text('Review profiles again'),
            ),
          ),
          const SizedBox(height: 10),
          _OutlineRow(label: 'Undo last swipe', onTap: onUndo),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onAdjustFilters,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Center(
                child: Text(
                  'Adjust filters',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            label,
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
    );
  }
}

class _OutlineRow extends StatelessWidget {
  const _OutlineRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
    );
  }
}
