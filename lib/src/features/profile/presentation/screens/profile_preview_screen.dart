import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/forms/form_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../settings/presentation/controllers/settings_controllers.dart';
import '../controllers/profile_controllers.dart';
import '../widgets/public_profile_view.dart';

/// The user's profile exactly as other people see it, from the server's own
/// public view of it.
class ProfilePreviewScreen extends ConsumerWidget {
  const ProfilePreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(ownPreviewProvider);
    final settings = ref.watch(userSettingsProvider).value;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'How others see you',
              subtitle: 'This is your profile as people see it in Kinvo',
              leading: HeaderBackButton(),
            ),
            Expanded(
              child: switch (preview) {
                AsyncValue(value: final profile?) => ListView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                  children: [
                    PublicProfilePhotoHeader(
                      user: profile.user,
                      accent: AppColors.purpleLight,
                      photos: profile.photos,
                    ),
                    const SizedBox(height: 16),
                    PublicProfileDetails(profile: profile),
                    if (settings != null) ...[
                      const SizedBox(height: 20),
                      _PrivacyNote(
                        showsDistance: settings.showDistance,
                        showsActivity: settings.showLastActive,
                      ),
                    ],
                  ],
                ),
                AsyncValue(:final error?) => ListView(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                  children: [
                    LoadFailedCard(
                      message: saveFailureMessage(error),
                      onRetry: () => ref.invalidate(ownPreviewProvider),
                    ),
                  ],
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

/// What the preview can't show: each viewer sees their own distance to the
/// user, and when they were last active, unless the user hides those.
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({
    required this.showsDistance,
    required this.showsActivity,
  });

  final bool showsDistance;
  final bool showsActivity;

  @override
  Widget build(BuildContext context) {
    final distance = showsDistance
        ? 'People also see roughly how far away you are.'
        : 'Your distance is hidden.';
    final activity = showsActivity
        ? 'Your matches see when you were last active.'
        : 'When you were last active is hidden.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.privacy_tip_outlined,
            size: 18,
            color: AppColors.purple,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$distance $activity You can change this in Privacy.',
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
