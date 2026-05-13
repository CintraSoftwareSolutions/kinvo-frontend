import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/home_controller.dart';
import '../../domain/discover_mode.dart';
import '../widgets/deck_controls.dart';
import '../widgets/discover_header.dart';
import '../widgets/discover_info_card.dart';
import '../widgets/profile_card.dart';

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(activeModeProvider);
    final badges = ref.watch(homeBadgeCountsProvider);

    return Column(
      children: [
        DiscoverHeader(
          mode: mode,
          notificationCount: badges.notifications,
          onFiltersTap: () => _showModePicker(context, ref),
        ),
        const Divider(height: 1, color: Color(0xFFEDEFF5)),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DiscoverInfoCard(mode: mode),
                const SizedBox(height: 18),
                ProfileCard(mode: mode),
                const SizedBox(height: 8),
                DeckControls(mode: mode),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showModePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final activeId = ref.read(activeModeIdProvider);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const Text(
                  'Switch mode',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                for (final m in DiscoverModes.all)
                  _ModeRow(
                    mode: m,
                    selected: m.id == activeId,
                    onTap: () {
                      ref
                          .read(activeModeIdProvider.notifier)
                          .state = m.id;
                      Navigator.of(sheetContext).pop();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final DiscoverMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: selected ? mode.primarySoft : const Color(0xFFF6F7FB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? mode.primary : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: mode.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              mode.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (selected)
              Icon(Icons.check_rounded, size: 18, color: mode.primary),
          ],
        ),
      ),
    );
  }
}
