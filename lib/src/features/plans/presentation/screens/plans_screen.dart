import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/flow_widgets.dart';
import '../../../../core/widgets/page_header.dart';
import '../../data/plans_repository.dart';
import '../controllers/plans_controllers.dart';
import '../widgets/plan_card.dart';

/// The Plans tab: plans with the user's matches, by where they stand.
class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(plansTabProvider);
    final awaiting = ref.watch(plansAwaitingAnswerProvider).value ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Plans',
          subtitle: 'Dates and meetups with your matches',
          trailing: Tooltip(
            message: 'New plan',
            child: Semantics(
              button: true,
              label: 'New plan',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => context.push(AppRoutes.planComposer),
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
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: _Tabs(
            selected: tab,
            awaiting: awaiting,
            onChanged: ref.read(plansTabProvider.notifier).select,
          ),
        ),
        Expanded(
          child: _PlansList(key: ValueKey(tab), tab: tab),
        ),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.selected,
    required this.awaiting,
    required this.onChanged,
  });

  final PlansTab selected;

  /// Plans waiting on the user's answer, counted on the Pending tab.
  final int awaiting;

  final ValueChanged<PlansTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final tab in PlansTab.values) ...[
          Flexible(
            child: Semantics(
              button: true,
              selected: tab == selected,
              label: tab == PlansTab.pending && awaiting > 0
                  ? '${_label(tab)}, $awaiting waiting for your answer'
                  : _label(tab),
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => onChanged(tab),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: tab == selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: tab == selected
                        ? const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _label(tab),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: tab == selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: tab == selected
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                      if (tab == PlansTab.pending && awaiting > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.purple,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$awaiting',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ],
    );
  }

  static String _label(PlansTab tab) {
    return switch (tab) {
      PlansTab.upcoming => 'Upcoming',
      PlansTab.pending => 'Pending',
      PlansTab.drafts => 'Drafts',
      PlansTab.history => 'History',
    };
  }
}

class _PlansList extends ConsumerWidget {
  const _PlansList({required this.tab, super.key});

  final PlansTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = plansListProvider(tab);
    final plans = ref.watch(provider);
    final notifier = ref.read(provider.notifier);

    Future<void> refresh() async {
      try {
        await notifier.refresh();
      } on Object {
        // The failure shows in place of the list, with a way to try again.
      }
    }

    final list = plans.value;
    if (list == null) {
      if (plans.hasError) {
        return _LoadFailed(
          message: plans.error is ApiException
              ? (plans.error! as ApiException).message
              : 'Something went wrong. Please try again.',
          onRetry: () => ref.invalidate(provider),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 400) notifier.loadMore();
          return false;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          children: [
            if (list.items.isEmpty)
              _Empty(tab: tab)
            else
              for (final plan in list.items) ...[
                PlanCard(plan: plan),
                const SizedBox(height: 12),
              ],
            if (list.isLoadingMore)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (list.loadMoreFailed)
              TextButton(
                onPressed: notifier.loadMore,
                child: const Text("More didn't load. Try again"),
              ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.tab});

  final PlansTab tab;

  @override
  Widget build(BuildContext context) {
    final (icon, title, message) = switch (tab) {
      PlansTab.upcoming => (
        Icons.event_available_outlined,
        'No plans yet',
        'Suggest a plan to one of your matches. Confirmed plans show here.',
      ),
      PlansTab.pending => (
        Icons.hourglass_empty_rounded,
        'Nothing waiting',
        'Plans you send, and plans sent to you, wait here for an answer.',
      ),
      PlansTab.drafts => (
        Icons.edit_note_rounded,
        'No drafts',
        'Save a plan as a draft to finish it later. Only you can see it.',
      ),
      PlansTab.history => (
        Icons.history_rounded,
        'No past plans',
        'Plans that happened, were declined or were called off show here.',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.surfaceSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 26, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          if (tab == PlansTab.upcoming) ...[
            const SizedBox(height: 16),
            PrimaryActionButton(
              label: 'New plan',
              borderRadius: 999,
              onPressed: () => context.push(AppRoutes.planComposer),
            ),
          ],
        ],
      ),
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
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              const Text(
                "Your plans didn't load",
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
