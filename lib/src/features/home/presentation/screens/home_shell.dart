import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ads/ads_controller.dart';
import '../../../../core/ads/banner_slot.dart';
import '../../../../core/assets/app_assets.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gradient_scaffold.dart';
import '../../../chat/data/live_updates.dart';
import '../../../chat/domain/live_update.dart';
import '../../../notifications/presentation/controllers/notifications_controllers.dart';
import '../../../notifications/presentation/widgets/push_invitation_sheet.dart';
import '../controllers/home_badges.dart';
import '../widgets/home_bottom_nav.dart';

/// The five tabs and their bottom navigation. Each tab keeps its own
/// navigation stack and state while another is shown.
///
/// Also announces new matches, wherever in the app the user is, and once
/// invites the user to turn notifications on.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  /// How long a new match stays announced.
  static const _announcementDuration = Duration(seconds: 6);

  /// How long the tabs show before the notifications invitation, so it
  /// doesn't land on top of whatever just opened.
  static const _invitationDelay = Duration(seconds: 2);

  /// The screens a banner may sit under, for accounts that see ads.
  static const _bannerPaths = {
    AppRoutes.matches,
    AppRoutes.plans,
    AppRoutes.more,
  };

  late final StreamSubscription<LiveUpdate> _updates;
  bool _inviting = false;

  @override
  void initState() {
    super.initState();
    _updates = ref.read(liveUpdatesProvider).stream.listen((update) {
      if (update case MatchCreated(:final match)) {
        _announceMatch(match.user.displayName, match.conversationId);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_updates.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ads live as long as the home screen, for accounts that see them:
    // Google's consent message belongs at launch rather than whenever the
    // first banner happens to show, and an interstitial should be loaded
    // before one can be due. A listener, not a read: Riverpod pauses a
    // provider nothing listens to, and a paused one loads nothing. For anyone
    // who doesn't see ads this settles at once and asks nothing.
    ref.listen(interstitialAdsProvider, (_, _) {});
    ref.listen(pushInvitationProvider, (_, invite) {
      if (invite.value == true) unawaited(_inviteToNotifications());
    });
    final badges = ref.watch(homeBadgeCountsProvider);
    final navigationShell = widget.navigationShell;

    // In the same order as the router's branches.
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
      HomeNavItem(icon: AppAssets.navMore, label: 'More', badge: badges.more),
    ];

    return GradientScaffold(
      background: AppColors.lightBackground,
      child: Column(
        children: [
          Expanded(child: navigationShell),
          // Only on these tabs' own screens: never over the deck, where the
          // swipe buttons are, and never on anything opened from a tab.
          if (_bannerPaths.contains(GoRouter.of(context).state.uri.path))
            const BannerSlot(),
          HomeBottomNav(
            items: navItems,
            currentIndex: navigationShell.currentIndex,
            onSelected: _selectTab,
          ),
        ],
      ),
    );
  }

  void _announceMatch(String name, String? conversationId) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text("It's a match! You and $name like each other."),
          duration: _announcementDuration,
          persist: false,
          action: conversationId == null
              ? null
              : SnackBarAction(
                  label: 'Say hi',
                  onPressed: () => context.push(AppRoutes.chat(conversationId)),
                ),
        ),
      );
  }

  Future<void> _inviteToNotifications() async {
    if (_inviting) return;
    _inviting = true;
    await Future<void>.delayed(_invitationDelay);
    if (!mounted) return;

    // Recorded first, so it's never offered twice, whatever happens next.
    await ref.read(pushInvitationProvider.notifier).offered();
    if (!mounted) return;
    final accepted = await showPushInvitationSheet(context);
    if (!accepted || !mounted) return;
    await ref.read(pushPermissionProvider.notifier).request();
  }

  /// Tapping the tab that's already open returns it to its first screen.
  void _selectTab(int index) {
    final navigationShell = widget.navigationShell;
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
