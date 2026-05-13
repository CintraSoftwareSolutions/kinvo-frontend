import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/device_preview_shell.dart';
import '../controllers/home_controller.dart';
import '../widgets/home_bottom_nav.dart';
import 'discover_screen.dart';
import 'placeholder_tab_screen.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(homeTabIndexProvider);
    final badges = ref.watch(homeBadgeCountsProvider);

    final navItems = <HomeNavItem>[
      const HomeNavItem(icon: AppAssets.navDiscover, label: 'Discover'),
      HomeNavItem(
        icon: AppAssets.navMatches,
        label: 'Matches',
        badge: badges.matches,
      ),
      HomeNavItem(
        icon: AppAssets.navPlans,
        label: 'Plans',
        badge: badges.plans,
      ),
      const HomeNavItem(icon: AppAssets.navProfile, label: 'Profile'),
      HomeNavItem(
        icon: AppAssets.navMore,
        label: 'More',
        badge: badges.more,
      ),
    ];

    return DevicePreviewShell(
      background: AppColors.lightBackground,
      child: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: index,
              children: const [
                DiscoverScreen(),
                PlaceholderTabScreen(
                  title: 'Matches',
                  subtitle:
                      'Your conversations and connections will land here.',
                  iconAsset: AppAssets.navMatches,
                ),
                PlaceholderTabScreen(
                  title: 'Plans',
                  subtitle:
                      'Schedule meetups, study sessions, and dining plans.',
                  iconAsset: AppAssets.navPlans,
                ),
                PlaceholderTabScreen(
                  title: 'Profile',
                  subtitle:
                      'Manage your Kinvo profile, modes, and trust settings.',
                  iconAsset: AppAssets.navProfile,
                ),
                PlaceholderTabScreen(
                  title: 'More',
                  subtitle:
                      'Notifications, safety center, privacy controls and more.',
                  iconAsset: AppAssets.navMore,
                ),
              ],
            ),
          ),
          HomeBottomNav(
            items: navItems,
            currentIndex: index,
            onSelected: (i) =>
                ref.read(homeTabIndexProvider.notifier).state = i,
          ),
        ],
      ),
    );
  }
}
