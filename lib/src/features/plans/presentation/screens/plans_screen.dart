import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/page_header.dart';
import '../../domain/plan.dart';
import '../controllers/plans_controller.dart';

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(plansControllerProvider);
    final upcoming = plans.where((p) => p.status == PlanStatus.upcoming).length;
    final pending = plans.where((p) => p.status == PlanStatus.pending).length;
    final history = plans
        .where((p) =>
            p.status == PlanStatus.completed ||
            p.status == PlanStatus.cancelled)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Plans',
          subtitle: 'Confirmed dates, pending invites, and drafts',
          trailing: GestureDetector(
            onTap: () =>
                Navigator.of(context).pushNamed(AppRoutes.planComposer),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.purple,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusSummary(
                  upcoming: upcoming,
                  pending: pending,
                  history: history,
                ),
                const SizedBox(height: 14),
                for (final p in plans) ...[
                  _PlanCard(plan: p),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({
    required this.upcoming,
    required this.pending,
    required this.history,
  });

  final int upcoming;
  final int pending;
  final int history;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _StatusCell(
                label: 'UPCOMING',
                value: '$upcoming',
                color: const Color(0xFF10B981),
                tint: const Color(0xFFECFDF5),
                subtitle: 'Confirmed plans ready to go.',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatusCell(
                label: 'PENDING',
                value: '$pending',
                color: const Color(0xFFEA580C),
                tint: const Color(0xFFFFF7ED),
                subtitle: 'Invites waiting on the other person.',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatusCell(
                label: 'HISTORY',
                value: '$history',
                color: AppColors.textSecondary,
                tint: const Color(0xFFF6F7FB),
                subtitle: 'Completed or closed plans.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({
    required this.label,
    required this.value,
    required this.color,
    required this.tint,
    required this.subtitle,
  });

  final String label;
  final String value;
  final Color color;
  final Color tint;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});

  final Plan plan;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  plan.attendeeAvatar,
                  width: 46,
                  height: 46,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 46,
                    height: 46,
                    color: AppColors.purpleSoft,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  plan.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Color(plan.modeColor),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(status: plan.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.venue,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${plan.attendeeName} | ${plan.dateTime}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.divider),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('View details'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Share plan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final PlanStatus status;

  @override
  Widget build(BuildContext context) {
    final cfg = _config(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cfg.$2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        cfg.$1,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: cfg.$3,
        ),
      ),
    );
  }

  (String, Color, Color) _config(PlanStatus s) {
    switch (s) {
      case PlanStatus.upcoming:
        return ('confirmed', const Color(0xFFD1FAE5), const Color(0xFF10B981));
      case PlanStatus.pending:
        return ('pending', const Color(0xFFFED7AA), const Color(0xFFC2410C));
      case PlanStatus.completed:
        return ('completed', AppColors.surfaceSoft, AppColors.textSecondary);
      case PlanStatus.cancelled:
        return ('cancelled', const Color(0xFFFFE4E8), const Color(0xFFEF4458));
    }
  }
}
