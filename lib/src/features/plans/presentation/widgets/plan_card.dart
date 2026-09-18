import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/time/clock.dart';
import '../../../modes/presentation/mode_presentation.dart';
import '../../../profile/presentation/widgets/person_photo.dart';
import '../../domain/plan.dart';
import '../controllers/plans_controllers.dart';
import '../plan_presentation.dart';

/// A plan in a list: where, with whom and when, and its state. Opens the
/// plan, and answers it in place when it waits on the user.
class PlanCard extends ConsumerStatefulWidget {
  const PlanCard({required this.plan, super.key});

  final Plan plan;

  @override
  ConsumerState<PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends ConsumerState<PlanCard> {
  bool _answering = false;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final now = ref.watch(clockProvider)();
    final badge = planBadge(plan, now);
    final when = planTime(context, plan.scheduledAt);

    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: () => context.push(AppRoutes.plan(plan.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                button: true,
                label:
                    '${plan.placeName}, with ${plan.user.displayName}, '
                    '$when, ${badge.label}',
                excludeSemantics: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 46,
                        height: 46,
                        child: PersonPhoto(
                          url: plan.user.photoUrl,
                          name: plan.user.displayName,
                          color: modeColors(plan.mode).primary,
                          initialSize: 20,
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
                                child: Text(
                                  plan.placeName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              PlanBadgePill(badge: badge),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'With ${plan.user.displayName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            when,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
              ),
              if (plan.awaitingMyResponse) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _answering ? null : () => _answer(false),
                        style: _buttonStyle(outlined: true),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _answering ? null : () => _answer(true),
                        style: _buttonStyle(outlined: false),
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _answer(bool accept) async {
    setState(() => _answering = true);
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ref
        .read(planActionsProvider)
        .answer(widget.plan, accept: accept);
    if (mounted) setState(() => _answering = false);

    final message = switch (outcome) {
      PlanSaved() when accept => "You're on. It's in Upcoming.",
      PlanSaved() => 'Plan declined.',
      PlanRefused(:final message) => message,
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static ButtonStyle _buttonStyle({required bool outlined}) {
    const shape = StadiumBorder();
    const padding = EdgeInsets.symmetric(vertical: 12);
    const text = TextStyle(fontSize: 13, fontWeight: FontWeight.w700);
    if (outlined) {
      return OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.divider),
        padding: padding,
        shape: shape,
        textStyle: text,
      );
    }
    return FilledButton.styleFrom(
      backgroundColor: AppColors.purple,
      foregroundColor: Colors.white,
      padding: padding,
      shape: shape,
      textStyle: text,
    );
  }
}

/// A plan's state, as a small coloured pill.
class PlanBadgePill extends StatelessWidget {
  const PlanBadgePill({required this.badge, super.key});

  final PlanBadge badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badge.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        badge.label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: badge.foreground,
        ),
      ),
    );
  }
}
