import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/kinvo_colors.dart';
import 'ads_controller.dart';
import 'ads_platform.dart';

/// Where a banner may go: along the bottom of a screen, above the navigation
/// bar.
///
/// Takes no room at all for anyone who doesn't see ads, and none until a
/// banner has loaded. When one has, a gap and a line keep it apart from the
/// navigation below it: an ad a thumb lands on while reaching for a tab is an
/// accidental click, and AdMob penalises the account that served it.
class BannerSlot extends ConsumerWidget {
  const BannerSlot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(adsProvider).showAds) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final line = context.colors.divider;
        return ref
            .read(adsPlatformProvider)
            .buildBanner(
              width: constraints.maxWidth,
              frame: (banner) => _frame(banner, line: line),
            );
      },
    );
  }

  static Widget _frame(Widget banner, {required Color line}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: line)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Center(child: banner),
      ),
    );
  }
}
