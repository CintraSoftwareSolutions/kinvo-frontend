import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinvo/src/core/assets/app_assets.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/core/theme/app_colors.dart';
import 'package:kinvo/src/core/widgets/device_preview_shell.dart';
import 'package:kinvo/src/core/widgets/flow_widgets.dart';

import '../controllers/profile_setup_controller.dart';

class ProfileSetupScreen extends ConsumerWidget {
  const ProfileSetupScreen({super.key});

  static const _genders = ['Woman', 'Man', 'Non-binary'];
  static const _purposes = [
    'Dating',
    'Networking',
    'Study Buddy',
    'Foodie Buddy',
  ];
  static const _lifestyle = [
    'Pet friendly',
    'Remote worker',
    'Weekend traveler',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileSetupControllerProvider);
    final controller = ref.read(profileSetupControllerProvider.notifier);

    return DevicePreviewShell(
      background: AppColors.lightBackground,
      child: FlowPageLayout(
        badgeText: 'Initial onboarding',
        badgeAsset: AppAssets.sparkle,
        title: 'Set up your profile',
        subtitle:
            'Gender identity, orientation, interests, lifestyle, and join-purpose are now part of the setup flow.',
        content: SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppInputCard(
                      label: 'NAME',
                      value: state.name,
                      assetName: AppAssets.user,
                      onChanged: controller.updateName,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppInputCard(
                      label: 'LOCATION',
                      value: state.location,
                      assetName: AppAssets.locationPin,
                      onChanged: controller.updateLocation,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Gender identity',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final gender in _genders)
                    OptionChip(
                      label: gender,
                      selected: state.genderIdentity == gender,
                      onTap: () => controller.selectGender(gender),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Purpose of joining',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final purpose in _purposes)
                    OptionChip(
                      label: purpose,
                      selected: state.purpose.contains(purpose),
                      selectedBackground: AppColors.purpleChip.withOpacity(.4),
                      selectedTextColor: AppColors.purple,
                      onTap: () => controller.togglePurpose(purpose),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Lifestyle preferences',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in _lifestyle)
                    OptionChip(
                      label: item,
                      selected: state.lifestyle.contains(item),
                      selectedBackground: AppColors.greenSoft.withOpacity(.4),
                      selectedTextColor: AppColors.green,
                      onTap: () => controller.toggleLifestyle(item),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              PrimaryActionButton(
                label: 'Finish setup',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile setup completed.')),
                  );
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.home,
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
