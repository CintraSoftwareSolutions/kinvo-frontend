import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/demo/demo_mode.dart';
import '../../../../core/forms/form_errors.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../discovery/presentation/controllers/discovery_modes_controller.dart';
import '../../../settings/presentation/controllers/settings_controllers.dart';
import '../../domain/own_profile.dart';
import '../controllers/profile_controllers.dart';
import '../widgets/person_photo.dart';

/// The Profile tab: the user's own profile, how complete it is, and the way
/// to change it.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(ownProfileProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Profile',
          subtitle: 'How you show up, and what would make it better',
          trailing: Tooltip(
            message: 'Settings',
            child: Semantics(
              button: true,
              label: 'Settings',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => context.push(AppRoutes.settings),
                behavior: HitTestBehavior.opaque,
                child: SvgPicture.asset(
                  AppAssets.settingsAlt,
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(
                    AppColors.textPrimary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: switch (profile) {
            AsyncValue(value: final profile?) => RefreshIndicator(
              onRefresh: () {
                ref
                  ..invalidate(profilePhotosProvider)
                  ..invalidate(ownProfileProvider);
                return ref.read(ownProfileProvider.future);
              },
              child: _ProfileBody(profile: profile),
            ),
            AsyncValue(:final error?) => ListView(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
              children: [
                LoadFailedCard(
                  message: saveFailureMessage(error),
                  onRetry: () => ref.invalidate(ownProfileProvider),
                ),
              ],
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ],
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile});

  final OwnProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(profilePhotosProvider).value?.photos ?? const [];
    final mainPhoto =
        photos.where((photo) => photo.isPrimary).firstOrNull ??
        photos.firstOrNull;
    final modes = ref.watch(discoveryModesProvider).value?.length;
    final onBreak =
        ref.watch(
          userSettingsProvider.select((settings) => settings.value?.isOnBreak),
        ) ??
        false;
    final work = [
      if (profile.jobTitle case final job? when job.trim().isNotEmpty) job,
      if (profile.organisation case final org? when org.trim().isNotEmpty) org,
    ].join(' at ');

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      children: [
        if (onBreak) ...[const _BreakBanner(), const SizedBox(height: 14)],
        Container(
          padding: const EdgeInsets.all(14),
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
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 1.05,
                  child: Semantics(
                    image: true,
                    label: 'Your main photo',
                    excludeSemantics: true,
                    child: PersonPhoto(
                      url: mainPhoto?.url,
                      name: profile.displayName,
                      color: AppColors.purpleLight,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      [
                        profile.displayName,
                        if (profile.age case final age?) '$age',
                      ].join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (profile.isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified_rounded,
                      size: 18,
                      color: AppColors.blue,
                      semanticLabel: 'Verified',
                    ),
                  ],
                ],
              ),
              if (work.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  work,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (profile.placeName case final place?) ...[
                const SizedBox(height: 2),
                Text(
                  place,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _StatBox(
                      label: 'Complete',
                      value: '${profile.completionPercentage}%',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatBox(label: 'Modes', value: '${modes ?? '–'}'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatBox(
                      label: 'Interests',
                      value: '${profile.interests.length}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (profile.completionMissing.isNotEmpty) ...[
          const SizedBox(height: 14),
          _CompletionCard(profile: profile),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () => context.push(AppRoutes.profileEdit),
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
                child: const Text('Edit profile'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => context.push(AppRoutes.profileReview),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.divider),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('How others see me'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (profile.isVerified)
          const SettingsGroup(
            children: [
              SettingsLink(
                icon: Icons.verified_user_outlined,
                title: "You're verified",
                description: 'People see a badge on your profile.',
                onTap: null,
              ),
            ],
          )
        else
          // Verification isn't connected to the server yet, so only builds
          // with the demo lead into it.
          DemoOnly(
            child: SettingsGroup(
              children: [
                SettingsLink(
                  icon: Icons.shield_outlined,
                  title: 'Get verified',
                  description: 'Show people you are who your photos say.',
                  onTap: () => context.push(AppRoutes.verificationMethods),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Said at the top while the user is taking a break from Discover.
class _BreakBanner extends StatelessWidget {
  const _BreakBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.purpleSoft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => context.push(AppRoutes.privacy),
        leading: const Icon(
          Icons.pause_circle_rounded,
          color: AppColors.purple,
        ),
        title: const Text(
          "You're taking a break",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: const Text(
          "Nobody new sees you in Discover. Tap to come back.",
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

/// What would make the profile more complete, most valuable first.
class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.profile});

  /// How many steps to suggest at once.
  static const _shown = 3;

  final OwnProfile profile;

  @override
  Widget build(BuildContext context) {
    final steps = profile.completionMissing.take(_shown);

    // A Material rather than a decorated box, so the rows' ripples show.
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: const Text(
                'Finish your profile',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Complete profiles are shown to more people.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: profile.completionPercentage / 100,
                minHeight: 6,
                color: AppColors.purple,
                backgroundColor: AppColors.surfaceSoft,
                semanticsLabel: 'Profile complete',
                semanticsValue: '${profile.completionPercentage}%',
              ),
            ),
            const SizedBox(height: 6),
            for (final step in steps)
              ListTile(
                onTap: () => context.push(AppRoutes.profileEdit),
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: AppColors.purple,
                  size: 20,
                ),
                minLeadingWidth: 20,
                title: Text(
                  step.label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
