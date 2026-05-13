import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/discover_mode.dart';

class ProfileSummaryCard extends StatelessWidget {
  const ProfileSummaryCard({required this.mode, this.onCtaTap, super.key});

  final DiscoverMode mode;
  final VoidCallback? onCtaTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
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
                  'Profile summary',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Conversation-ready context for a good first message.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onCtaTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              constraints: const BoxConstraints(maxWidth: 120),
              decoration: BoxDecoration(
                color: mode.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                mode.summaryCta,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: mode.primary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
