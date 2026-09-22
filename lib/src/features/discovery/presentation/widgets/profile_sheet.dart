import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/flow_widgets.dart';
import '../../../profile/domain/user_summary.dart';
import '../../../profile/presentation/widgets/public_profile_view.dart';
import '../controllers/discovery_actions.dart';

/// Shows [user]'s full profile in a sheet.
///
/// What's already known about them shows at once; the rest of the profile
/// loads underneath. [actions] adds buttons along the bottom, such as
/// answering a like.
Future<T?> showProfileSheet<T>(
  BuildContext context, {
  required UserSummary user,
  required Color accent,
  WidgetBuilder? actions,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ProfileSheet(user: user, accent: accent, actions: actions),
  );
}

class ProfileSheet extends ConsumerWidget {
  const ProfileSheet({
    required this.user,
    required this.accent,
    this.actions,
    super.key,
  });

  final UserSummary user;
  final Color accent;
  final WidgetBuilder? actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(publicProfileProvider(user.id));
    final actions = this.actions;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Column(
          children: [
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  PublicProfilePhotoHeader(
                    user: user,
                    accent: accent,
                    photos: profile.value?.photos ?? const [],
                  ),
                  const SizedBox(height: 16),
                  switch (profile) {
                    AsyncData(:final value) => PublicProfileDetails(
                      profile: value,
                    ),
                    AsyncError(:final error) => _LoadFailure(
                      message: error is ApiException
                          ? error.message
                          : 'Something went wrong. Please try again.',
                      onRetry: () =>
                          ref.invalidate(publicProfileProvider(user.id)),
                    ),
                    _ => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  },
                ],
              ),
            ),
            if (actions != null)
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.divider)),
                  ),
                  child: actions(context),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          FormErrorBanner(message: message),
          const SizedBox(height: 12),
          OutlineActionButton(
            label: 'Try again',
            onPressed: onRetry,
            foregroundColor: AppColors.textPrimary,
            borderColor: AppColors.divider,
          ),
        ],
      ),
    );
  }
}
