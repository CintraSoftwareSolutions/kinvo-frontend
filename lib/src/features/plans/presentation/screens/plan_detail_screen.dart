import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/network/api_error_code.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/widgets/flow_widgets.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../matches/data/matches_repository.dart';
import '../../../modes/presentation/mode_presentation.dart';
import '../../../profile/presentation/widgets/person_photo.dart';
import '../../domain/plan.dart';
import '../controllers/plans_controllers.dart';
import '../plan_presentation.dart';
import '../widgets/plan_card.dart';
import '../widgets/share_plan_sheet.dart';

/// One plan: where, when and with whom, and what the user can do with it
/// now.
class PlanDetailScreen extends ConsumerWidget {
  const PlanDetailScreen({required this.planId, super.key});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planProvider(planId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(title: 'Plan', leading: HeaderBackButton()),
            Expanded(
              child: switch (plan) {
                AsyncValue(value: final plan?) => _PlanBody(plan: plan),
                AsyncValue(
                  error: ApiErrorException(code: ApiErrorCode.notFound),
                ) =>
                  const _Gone(),
                AsyncValue(:final error?) => _LoadFailed(
                  message: error is ApiException
                      ? error.message
                      : 'Something went wrong. Please try again.',
                  onRetry: () => ref.invalidate(planProvider(planId)),
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanBody extends ConsumerStatefulWidget {
  const _PlanBody({required this.plan});

  final Plan plan;

  @override
  ConsumerState<_PlanBody> createState() => _PlanBodyState();
}

class _PlanBodyState extends ConsumerState<_PlanBody> {
  bool _busy = false;

  Plan get _plan => widget.plan;

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final now = ref.watch(clockProvider)();
    final name = plan.user.displayName;
    final duration = plan.durationMinutes;
    final notes = plan.notes?.trim() ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
      children: [
        SurfaceCard(
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: PersonPhoto(
                    url: plan.user.photoUrl,
                    name: name,
                    color: modeColors(plan.mode).primary,
                    initialSize: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'With $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _explanation(plan, now),
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PlanBadgePill(badge: planBadge(plan, now)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DetailRow(
                icon: venueIcon(plan.venue?.category),
                title: plan.placeName,
                subtitle: plan.address,
              ),
              const Divider(height: 24, color: AppColors.divider),
              _DetailRow(
                icon: Icons.event_outlined,
                title: planTime(context, plan.scheduledAt),
                subtitle: duration == null
                    ? null
                    : 'For ${durationLabel(duration)}',
              ),
              if (notes.isNotEmpty) ...[
                const Divider(height: 24, color: AppColors.divider),
                _DetailRow(icon: Icons.notes_rounded, title: notes),
              ],
              if (plan.sharedWithContacts > 0) ...[
                const Divider(height: 24, color: AppColors.divider),
                _DetailRow(
                  icon: Icons.shield_outlined,
                  title: plan.sharedWithContacts == 1
                      ? 'One of your trusted contacts knows'
                      : '${plan.sharedWithContacts} of your trusted contacts '
                            'know',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        ..._actions(plan, now),
      ],
    );
  }

  List<Widget> _actions(Plan plan, DateTime now) {
    final name = plan.user.displayName;
    return [
      if (plan.awaitingMyResponse)
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => _answer(accept: false),
                style: _outlined,
                child: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : () => _answer(accept: true),
                style: _filled,
                child: const Text('Accept'),
              ),
            ),
          ],
        )
      else if (plan.canSend(now))
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : _edit,
                style: _outlined,
                child: const Text('Edit'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : _send,
                style: _filled,
                child: Text('Send to $name', overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        )
      else if (plan.canEdit)
        OutlinedButton(
          onPressed: _busy ? null : _edit,
          style: _outlined,
          child: const Text('Edit plan'),
        ),
      if (plan.status == PlanStatus.confirmed && !plan.hasStarted(now)) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => showSharePlanSheet(context, plan),
          style: _outlined,
          icon: const Icon(Icons.shield_outlined, size: 18),
          label: const Text('Tell a trusted contact'),
        ),
      ],
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _busy ? null : _message,
        style: _outlined,
        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
        label: Text('Message $name', overflow: TextOverflow.ellipsis),
      ),
      if (plan.canDelete) ...[
        const SizedBox(height: 6),
        TextButton(
          onPressed: _busy ? null : _deleteDraft,
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Delete draft'),
        ),
      ] else if (plan.canCancel(now)) ...[
        const SizedBox(height: 6),
        TextButton(
          onPressed: _busy ? null : _cancel,
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Cancel plan'),
        ),
      ],
    ];
  }

  static String _explanation(Plan plan, DateTime now) {
    final name = plan.user.displayName;
    final started = plan.hasStarted(now);
    return switch (plan.status) {
      PlanStatus.draft =>
        "Only you can see this draft. Send it when it's ready.",
      PlanStatus.proposed when started =>
        'The time for this plan passed without an answer.',
      PlanStatus.proposed when plan.awaitingMyResponse =>
        '$name suggested this plan.',
      PlanStatus.proposed => 'Waiting for $name to answer.',
      PlanStatus.confirmed when started => 'You both said yes.',
      PlanStatus.confirmed => "You're both on.",
      PlanStatus.declined =>
        plan.isMine ? '$name said no to this one.' : 'You said no to this one.',
      PlanStatus.cancelled => 'This plan was called off.',
      PlanStatus.completed => 'This plan has passed.',
      PlanStatus.unknown => 'A plan with $name.',
    };
  }

  Future<void> _answer({required bool accept}) async {
    await _act(
      () => ref.read(planActionsProvider).answer(_plan, accept: accept),
      done: accept ? "You're on. It's in Upcoming." : 'Plan declined.',
    );
  }

  Future<void> _send() async {
    await _act(
      () => ref.read(planActionsProvider).send(_plan),
      done: 'Sent to ${_plan.user.displayName}.',
    );
  }

  Future<void> _cancel() async {
    final reason = await _askToCancel();
    if (reason == null) return;
    await _act(
      () => ref.read(planActionsProvider).cancel(_plan, reason: reason),
      done: '${_plan.user.displayName} has been told the plan is off.',
    );
  }

  Future<void> _deleteDraft() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete this draft?'),
        content: const Text("It hasn't been sent, so nobody else will know."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final error = await ref.read(planActionsProvider).deleteDraft(_plan);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      _say(messenger, error);
      return;
    }
    _say(messenger, 'Draft deleted.');
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(AppRoutes.plans);
    }
  }

  void _edit() {
    context.push(AppRoutes.editPlan(_plan.id));
  }

  Future<void> _message() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final match = await ref
          .read(matchesRepositoryProvider)
          .fetchMatch(_plan.matchId);
      final conversationId = match.conversationId;
      if (conversationId == null) {
        throw const ApiErrorException(
          code: ApiErrorCode.notFound,
          message: 'Not found.',
          statusCode: 404,
        );
      }
      await router.push(AppRoutes.chat(conversationId));
    } on ApiException catch (error) {
      _say(
        messenger,
        error is ApiErrorException && error.code == ApiErrorCode.notFound
            ? "You can't message ${_plan.user.displayName} any more."
            : error.message,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Runs [action], shows the plan as it came back, and says how it went.
  Future<void> _act(
    Future<PlanOutcome> Function() action, {
    required String done,
  }) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    switch (outcome) {
      case PlanSaved(:final plan):
        ref.read(planProvider(plan.id).notifier).show(plan);
        _say(messenger, done);
      case PlanRefused(:final message):
        _say(messenger, message);
    }
  }

  /// Asks whether to call the plan off. Returns the reason given, which may
  /// be empty, or `null` to keep it.
  Future<String?> _askToCancel() {
    return showDialog<String>(
      context: context,
      builder: (_) => _CancelDialog(name: _plan.user.displayName),
    );
  }

  static void _say(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static final _outlined = OutlinedButton.styleFrom(
    foregroundColor: AppColors.textPrimary,
    side: const BorderSide(color: AppColors.divider),
    backgroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: const StadiumBorder(),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
  );

  static final _filled = FilledButton.styleFrom(
    backgroundColor: AppColors.purple,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: const StadiumBorder(),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
  );
}

/// Asks whether to call a plan off, with an optional reason. Closes with the
/// reason, which may be empty, or with nothing to keep the plan.
class _CancelDialog extends StatefulWidget {
  const _CancelDialog({required this.name});

  final String name;

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  // Owned by the dialog, so it lasts until the dialog has finished closing.
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancel this plan?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("${widget.name} will be told it's off."),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            maxLength: 500,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Say why (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Keep plan'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_reason.text),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Cancel plan'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.purpleSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: AppColors.purple),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Gone extends StatelessWidget {
  const _Gone();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      children: [
        SurfaceCard(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: Column(
            children: [
              const Text(
                "This plan isn't available",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'It may have been deleted, or the match it belongs to has '
                'ended.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              PrimaryActionButton(
                label: 'Back to plans',
                onPressed: () => context.go(AppRoutes.plans),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      children: [
        SurfaceCard(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: Column(
            children: [
              const Text(
                "This plan didn't load",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              PrimaryActionButton(label: 'Try again', onPressed: onRetry),
            ],
          ),
        ),
      ],
    );
  }
}
