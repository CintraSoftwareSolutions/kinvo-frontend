import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/kinvo_colors.dart';
import '../../../notifications/presentation/controllers/notifications_controllers.dart';
import '../../../premium/domain/plans.dart';
import '../../../premium/presentation/controllers/premium_controllers.dart';
import '../../../profile/presentation/controllers/profile_controllers.dart';
import '../../../profile/presentation/widgets/person_photo.dart';
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
                const _NotificationsTile(),
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
            Semantics(
              header: true,
              child: Text(
                'More',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your account, safety, settings and support',
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

/// The way into the notifications, with how many are unread: the same count
/// as on the More tab, so the tab's number leads here.
class _NotificationsTile extends ConsumerWidget {
  const _NotificationsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationUnreadCountProvider).value ?? 0;
    return SettingsTile(
      icon: AppAssets.bell,
      iconBg: context.colors.dangerSoft,
      iconColor: context.colors.danger,
      title: 'Notifications',
      subtitle: 'Check match, message, and plan alerts.',
      badgeCount: unread,
      onTap: () => context.push(AppRoutes.notifications),
    );
  }
}

/// Who is signed in: their photo, their name, whether they are verified and
/// what plan they are on. Opens their profile as other people see it.
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
    final colors = context.colors;
    final profile = ref.watch(ownProfileProvider).value;
    final plan = ref.watch(currentPlanProvider).value;
    final photo = ref.watch(ownMainPhotoProvider);
    final name = profile?.displayName ?? 'Your profile';
    final details = [
      if (profile?.isVerified ?? false) 'Verified profile',
      ?_planLine(plan),
    ].join(' | ');
    void open() => context.push(AppRoutes.profileReview);

    return Semantics(
      button: true,
      label: details.isEmpty ? name : '$name, $details',
      hint: 'Shows your profile as other people see it',
      onTap: open,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: colors.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: colors.divider),
          ),
          child: InkWell(
            onTap: open,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  ClipOval(
                    child: SizedBox.square(
                      dimension: 48,
                      child: PersonPhoto(
                        url: photo?.url,
                        name: name,
                        color: colors.purpleLight,
                        initialSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        if (details.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            details,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'View',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
