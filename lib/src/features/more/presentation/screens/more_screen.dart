import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/kinvo_colors.dart';
import '../../../premium/domain/plans.dart';
import '../../../premium/presentation/controllers/premium_controllers.dart';
import '../../../profile/presentation/controllers/profile_controllers.dart';
import '../widgets/settings_tile.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _MoreHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _IdentityCard(),
                const SizedBox(height: 14),
                const _PlanTile(),
                const SizedBox(height: 10),
                SettingsTile(
                  icon: AppAssets.shield,
                  iconBg: context.colors.tint(Hue.indigo).soft,
                  iconColor: context.colors.tint(Hue.indigo).color,
                  title: 'Safety Center',
                  subtitle: 'Review trusted contacts, tips, and reports.',
                  onTap: () => context.push(AppRoutes.safetyCenter),
                ),
                const SizedBox(height: 10),
                SettingsTile(
                  icon: AppAssets.bell,
                  iconBg: context.colors.dangerSoft,
                  iconColor: context.colors.danger,
                  title: 'Notifications',
                  subtitle: 'Check match, message, and plan alerts.',
                  onTap: () => context.push(AppRoutes.notifications),
                ),
                const SizedBox(height: 10),
                SettingsTile(
                  icon: AppAssets.video,
                  iconBg: context.colors.purpleSoft,
                  iconColor: context.colors.purple,
                  title: 'Calls',
                  subtitle: 'Video and voice calls, and who you missed.',
                  onTap: () => context.push(AppRoutes.calls),
                ),
                const SizedBox(height: 10),
                SettingsTile(
                  icon: AppAssets.settingsAlt,
                  iconBg: context.colors.surfaceSoft,
                  iconColor: context.colors.textPrimary,
                  title: 'Privacy',
                  subtitle:
                      'What others see, taking a break, and your devices.',
                  onTap: () => context.push(AppRoutes.privacy),
                ),
                const SizedBox(height: 10),
                SettingsTile(
                  iconWidget: Icon(
                    Icons.public_outlined,
                    size: 20,
                    color: context.colors.textPrimary,
                  ),
                  iconBg: context.colors.surfaceSoft,
                  title: 'Support & guidelines',
                  subtitle: 'Help, the rules, and safety.',
                  onTap: () => context.push(AppRoutes.support),
                ),
                const SizedBox(height: 10),
                SettingsTile(
                  icon: AppAssets.contrast,
                  iconBg: context.colors.tint(Hue.purple).soft,
                  iconColor: context.colors.purple,
                  title: 'Theme & accessibility',
                  subtitle: 'Tune contrast, motion, text size, and dark mode.',
                  onTap: () => context.push(AppRoutes.theme),
                ),
                const SizedBox(height: 10),
                SettingsTile(
                  icon: AppAssets.settingsAlt,
                  iconBg: context.colors.surfaceSoft,
                  title: 'Settings',
                  subtitle: 'Filters, units, notifications and your account.',
                  onTap: () => context.push(AppRoutes.settings),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MoreHeader extends StatelessWidget {
  const _MoreHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.colors.divider),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadow,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'More',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Account hub, safety, support, and premium entry',
              style: TextStyle(
                fontSize: 12.5,
                color: context.colors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The way into the plans: an offer while the account is free, and the plan
/// it is on once it has one.
class _PlanTile extends ConsumerWidget {
  const _PlanTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(currentPlanProvider).value?.live;
    final until = live == null
        ? null
        : MaterialLocalizations.of(
            context,
          ).formatMediumDate(live.periodEnd.toLocal());

    return SettingsTile(
      iconWidget: Icon(
        Icons.workspace_premium_rounded,
        size: 22,
        color: context.colors.tint(Hue.amber).onSoft,
      ),
      iconBg: context.colors.tint(Hue.amber).soft,
      title: live == null
          ? 'Upgrade to Premium'
          : 'Your plan: ${live.tier?.label ?? 'Paid plan'}',
      subtitle: live == null
          ? 'Unlock multi-mode access and advanced controls.'
          : [
              if (live.renews) 'Renews $until' else 'Until $until',
              if (live.isTest) 'test plan',
            ].join(' · '),
      onTap: () => context.push(AppRoutes.premium),
    );
  }
}

/// Who is signed in, whether they are verified, and what plan they are on.
class _IdentityCard extends ConsumerWidget {
  const _IdentityCard();

  /// "Premium member", "Free plan" — or nothing while the plan is loading,
  /// rather than a guess.
  static String? _planLine(CurrentPlan? plan) {
    if (plan == null) return null;
    return switch (plan.tier) {
      PlanTier.free => 'Free plan',
      final PlanTier tier => '${tier.label} member',
      null => 'Member',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(ownProfileProvider).value;
    final plan = ref.watch(currentPlanProvider).value;
    final details = [
      if (profile?.isVerified ?? false) 'Verified profile',
      ?_planLine(plan),
    ].join(' | ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.divider),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.colors.tint(Hue.purple).soft,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: context.colors.purple,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?.displayName ?? 'Your profile',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        details,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.colors.surfaceSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'View',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.surfaceSoft.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: SvgPicture.asset(
                    AppAssets.sparkles,
                    width: 18,
                    height: 18,
                    colorFilter: ColorFilter.mode(
                      context.colors.purple,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Workspace status',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Discovery, plans, profile, safety, and notifications all have local working paths.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.45,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
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
