import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/flow_widgets.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../data/plan_purchases.dart';
import '../../domain/plans.dart';
import '../controllers/premium_controllers.dart';

/// The plans on sale, the one the account is on, and buying.
///
/// Everything shown comes from the server: the prices, what each plan
/// includes, and whether buying is possible here at all. On staging buying is
/// a test purchase — the plan starts at once and no money is taken — and the
/// screen says so beside the button, never in small print elsewhere.
class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  /// What the person has picked. Null until they pick, so the plan they are
  /// on — or Premium, yearly — is where the screen starts.
  PlanTier? _tier;
  BillingCycle? _cycle;

  void _retry() {
    ref.invalidate(planCatalogueProvider);
    ref.read(currentPlanProvider.notifier).refresh().ignore();
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(planCatalogueProvider);
    final current = ref.watch(currentPlanProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Premium',
              subtitle: 'Pick the plan that fits how you use Kinvo',
              leading: HeaderBackButton(),
            ),
            Expanded(
              child: switch ((catalogue, current)) {
                (AsyncData(value: final plans), AsyncData(value: final plan))
                    when plans.plans.isNotEmpty =>
                  _plans(context, plans, plan),
                (AsyncData(value: final plans), AsyncData())
                    when plans.plans.isEmpty =>
                  _message(
                    LoadFailedCard(
                      message: 'There are no plans on sale right now.',
                      onRetry: _retry,
                    ),
                  ),
                (AsyncError(), _) || (_, AsyncError()) => _message(
                  LoadFailedCard(
                    message:
                        'We could not load the plans. Check your connection '
                        'and try again.',
                    onRetry: _retry,
                  ),
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      child: child,
    );
  }

  Widget _plans(
    BuildContext context,
    PlanCatalogue catalogue,
    CurrentPlan current,
  ) {
    final activity = ref.watch(premiumActivityProvider);
    final purchases = ref.watch(planPurchasesProvider(catalogue.purchaseMode));

    final live = current.live;
    final tiers = catalogue.tiers;
    final tier =
        _tier ??
        switch (live?.tier) {
          final PlanTier onTier? when tiers.contains(onTier) => onTier,
          _ => tiers.contains(PlanTier.premium) ? PlanTier.premium : tiers.last,
        };
    final options = catalogue.plansFor(tier);
    final cycle =
        _cycle ??
        (live?.tier == tier ? live?.cycle : null) ??
        BillingCycle.yearly;
    final selected = options.firstWhere(
      (plan) => plan.cycle == cycle,
      orElse: () => options.first,
    );

    // A column, not a lazy list: the page is short, and every part of it —
    // the price, the button, the words about what the button does — has to
    // be there together.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (live != null) ...[
            _YourPlanCard(
              subscription: live,
              plan: catalogue.bySlug(live.productSlug),
              canEnd: live.isTest && purchases.sellsTestPlans,
              isEnding: activity.isEnding,
              onEnd: activity.isBusy ? null : () => _endTestPlan(purchases),
            ),
            const SizedBox(height: 14),
          ],
          if (tiers.length > 1) ...[
            _TierToggle(
              tiers: tiers,
              selected: tier,
              onChanged: activity.isBusy
                  ? null
                  : (value) => setState(() {
                      _tier = value;
                      _cycle = cycle;
                    }),
            ),
            const SizedBox(height: 12),
          ],
          _TierCard(tier: tier, features: selected.features),
          const SizedBox(height: 12),
          for (final plan in options) ...[
            _PlanCard(
              plan: plan,
              selected: plan == selected,
              isCurrent: current.isOn(plan),
              saving: catalogue.savingOverMonthly(plan),
              onTap: activity.isBusy
                  ? null
                  : () => setState(() {
                      _tier = plan.tier;
                      _cycle = plan.cycle;
                    }),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          PrimaryActionButton(
            label: _buttonLabel(purchases, current, selected),
            borderRadius: 999,
            loading: activity.buying == selected,
            onPressed:
                !purchases.canBuy ||
                    selected.price == null ||
                    current.isOn(selected) ||
                    activity.isBusy
                ? null
                : () => _buy(selected, purchases),
          ),
          const SizedBox(height: 10),
          Text(
            purchases.canBuy
                ? purchases.sellsTestPlans
                      ? 'Test purchase: the plan starts straight away and no '
                            'money is taken. It runs for a '
                            '${selected.cycle == BillingCycle.monthly ? 'month' : 'year'} '
                            "and doesn't renew. Real payments come with the app "
                            'store release.'
                      : 'Payment is taken by the app store.'
                : "Buying isn't available in this version yet. The plans "
                      'above are what will be on sale.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          if (activity.error case final error?) ...[
            const SizedBox(height: 12),
            FormErrorBanner(message: error),
          ],
        ],
      ),
    );
  }

  /// What pressing the button would do, in its own words.
  static String _buttonLabel(
    PlanPurchases purchases,
    CurrentPlan current,
    Plan selected,
  ) {
    if (!purchases.canBuy) return 'Coming soon';
    if (selected.price == null) return 'Not on sale right now';
    if (current.isOn(selected)) return 'Your current plan';

    final onTier = current.live?.tier;
    if (onTier == null || onTier == PlanTier.free) {
      return 'Upgrade to ${selected.tier.label}';
    }
    if (onTier == selected.tier) {
      return 'Switch to ${selected.cycle.label.toLowerCase()}';
    }
    return selected.tier.index > onTier.index
        ? 'Upgrade to ${selected.tier.label}'
        : 'Switch to ${selected.tier.label}';
  }

  Future<void> _buy(Plan plan, PlanPurchases purchases) async {
    final result = await ref
        .read(premiumActivityProvider.notifier)
        .buy(plan, purchases);
    if (result == null || !mounted) return;

    final until = result.live?.periodEnd;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          until == null
              ? "You're on ${plan.tier.label}."
              : "You're on ${plan.tier.label} until ${_date(context, until)}.",
        ),
      ),
    );
  }

  Future<void> _endTestPlan(PlanPurchases purchases) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End your test plan?'),
        content: const Text(
          "You'll be back on the free plan straight away. You can start "
          'another test plan whenever you like.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('End it'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await ref
        .read(premiumActivityProvider.notifier)
        .endTestPlan(purchases);
    if (result == null || !mounted) return;

    setState(() {
      _tier = null;
      _cycle = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Your test plan has ended. You're on the free plan."),
      ),
    );
  }
}

String _date(BuildContext context, DateTime moment) {
  return MaterialLocalizations.of(context).formatMediumDate(moment.toLocal());
}

/// The plan the account is on, and — for a test plan — the way out of it.
class _YourPlanCard extends StatelessWidget {
  const _YourPlanCard({
    required this.subscription,
    required this.plan,
    required this.canEnd,
    required this.isEnding,
    required this.onEnd,
  });

  final PlanSubscription subscription;

  /// The catalogue's entry for it, for its name. Null for a plan no longer on
  /// sale, which is still the account's plan until it ends.
  final Plan? plan;

  final bool canEnd;
  final bool isEnding;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    final tier = subscription.tier?.label ?? 'Paid plan';
    final cycle = subscription.cycle?.label;
    final until = _date(context, subscription.periodEnd);

    return SurfaceCard(
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'YOUR PLAN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            cycle == null ? tier : '$tier · $cycle',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subscription.renews ? 'Renews $until' : 'Until $until',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (subscription.isTest) ...[
            const SizedBox(height: 10),
            const _TestPlanNote(),
          ],
          if (canEnd) ...[
            const SizedBox(height: 12),
            OutlineActionButton(
              label: isEnding ? 'Ending…' : 'End test plan',
              onPressed: onEnd,
              // The button's default is for dark screens; this card is white.
              foregroundColor: AppColors.danger,
              borderColor: AppColors.danger,
            ),
          ],
        ],
      ),
    );
  }
}

class _TestPlanNote extends StatelessWidget {
  const _TestPlanNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.purpleSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.science_outlined, size: 16, color: AppColors.purple),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Test plan — no money was taken.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.purple,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Basic or Premium.
class _TierToggle extends StatelessWidget {
  const _TierToggle({
    required this.tiers,
    required this.selected,
    required this.onChanged,
  });

  final List<PlanTier> tiers;
  final PlanTier selected;
  final ValueChanged<PlanTier>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          for (final tier in tiers)
            Expanded(
              child: Semantics(
                button: true,
                selected: tier == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onChanged == null ? null : () => onChanged!(tier),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: tier == selected
                          ? AppColors.purple
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tier.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: tier == selected
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
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

/// What the tier includes, in the server's words.
class _TierCard extends StatelessWidget {
  const _TierCard({required this.tier, required this.features});

  final PlanTier tier;
  final List<String> features;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6E47CB), Color(0xFFA87EF6), Color(0xFFF59E0B)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KINVO ${tier.label.toUpperCase()}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Everything in the free plan, and',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One way to pay for the tier: its price, and what yearly saves.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.isCurrent,
    required this.saving,
    required this.onTap,
  });

  final Plan plan;
  final bool selected;
  final bool isCurrent;
  final int? saving;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final price = plan.price;
    final perMonth = price != null && plan.cycle.months > 1
        ? '${price.perMonth(plan.cycle.months).format()} a month'
        : null;
    final tag = isCurrent
        ? 'Current plan'
        : saving == null
        ? null
        : 'Save $saving%';

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.purple : AppColors.divider,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    plan.cycle.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (tag != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? AppColors.greenSoft
                            : AppColors.purpleChip,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: isCurrent ? AppColors.green : AppColors.purple,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                price?.format() ?? 'Not on sale right now',
                style: TextStyle(
                  fontSize: price == null ? 14 : 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  switch (plan.cycle) {
                    BillingCycle.monthly => 'a month',
                    BillingCycle.quarterly => 'every three months',
                    BillingCycle.yearly => 'a year',
                  },
                  ?perMonth,
                ].join(' · '),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
