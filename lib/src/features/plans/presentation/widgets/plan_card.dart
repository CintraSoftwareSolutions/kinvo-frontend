import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/kinvo_colors.dart';
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
      color: context.colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: context.colors.divider),
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
                          color: context.colors.mode(plan.mode).color,
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
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.textPrimary,
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
                            style: TextStyle(
                              fontSize: 12.5,
                              color: context.colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            when,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: context.colors.textMuted,
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
                        style: _buttonStyle(context, outlined: true),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _answering ? null : () => _answer(true),
                        style: _buttonStyle(context, outlined: false),
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

  static ButtonStyle _buttonStyle(
    BuildContext context, {
    required bool outlined,
  }) {
    final colors = context.colors;
    const shape = StadiumBorder();
    const padding = EdgeInsets.symmetric(vertical: 12);
    const text = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w700,
    );
    if (outlined) {
      return OutlinedButton.styleFrom(
        foregroundColor: colors.textPrimary,
        side: BorderSide(color: colors.divider),
        padding: padding,
        shape: shape,
        textStyle: text,
      );
    }
    return FilledButton.styleFrom(
      backgroundColor: colors.purple,
      foregroundColor: colors.onAccent,
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
    final colors = context.colors;
    final (background, foreground) = switch (badge.hue) {
      final hue? => (colors.tint(hue).soft, colors.tint(hue).onSoft),
      null => (colors.surfaceSoft, colors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        badge.label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
