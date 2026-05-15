import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/page_header.dart';
import '../../domain/connection.dart';
import '../controllers/connections_controller.dart';

class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(connectionFilterProvider);
    final list = ref.watch(connectionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Connections',
          subtitle: 'Matches, unread messages, and recent activity',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              '3 unread',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatsCard(),
                const SizedBox(height: 18),
                _FilterTabs(
                  selected: filter,
                  onChanged: (f) =>
                      ref.read(connectionFilterProvider.notifier).state = f,
                ),
                const SizedBox(height: 14),
                if (list.isEmpty)
                  _EmptyConnections(filter: filter)
                else
                  _ConnectionsCard(
                    items: list,
                    onTap: (c) => Navigator.of(context).pushNamed(
                      AppRoutes.chat,
                      arguments: c,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0C132A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: const [
          Expanded(
            child: _StatCell(
              label: 'Matches',
              value: '3',
              tint: Color(0xFFFCE7F0),
              iconColor: Color(0xFFE60076),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _StatCell(
              label: 'Unread',
              value: '3',
              tint: Color(0xFFDBEAFE),
              iconColor: Color(0xFF3B82F6),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _StatCell(
              label: 'Plans',
              value: '6',
              tint: Color(0xFFD1FAE5),
              iconColor: Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.tint,
    required this.iconColor,
  });

  final String label;
  final String value;
  final Color tint;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: SvgPicture.asset(
                AppAssets.usersPink,
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({required this.selected, required this.onChanged});

  final ConnectionFilter selected;
  final ValueChanged<ConnectionFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final f in ConnectionFilter.values) ...[
          GestureDetector(
            onTap: () => onChanged(f),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: f == selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: f == selected
                    ? const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                _label(f),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      f == selected ? FontWeight.w700 : FontWeight.w500,
                  color: f == selected
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ],
    );
  }

  String _label(ConnectionFilter f) {
    switch (f) {
      case ConnectionFilter.matches:
        return 'Matches';
      case ConnectionFilter.requests:
        return 'Requests';
      case ConnectionFilter.archived:
        return 'Archived';
    }
  }
}

class _ConnectionsCard extends StatelessWidget {
  const _ConnectionsCard({required this.items, required this.onTap});

  final List<Connection> items;
  final ValueChanged<Connection> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0C132A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _ConnectionRow(
              connection: items[i],
              onTap: () => onTap(items[i]),
            ),
            if (i < items.length - 1)
              const Divider(
                height: 1,
                color: AppColors.divider,
                indent: 78,
                endIndent: 14,
              ),
          ],
        ],
      ),
    );
  }
}

class _ConnectionRow extends StatelessWidget {
  const _ConnectionRow({required this.connection, required this.onTap});

  final Connection connection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: [
            _AvatarWithBadges(
              avatar: connection.avatar,
              unread: connection.unread,
              online: connection.online,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        connection.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const _VerifiedShield(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    connection.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              connection.timeAgo,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarWithBadges extends StatelessWidget {
  const _AvatarWithBadges({
    required this.avatar,
    required this.unread,
    required this.online,
  });

  final String avatar;
  final int unread;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Image.asset(
              avatar,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 52,
                height: 52,
                color: AppColors.purpleSoft,
                child: const Center(
                  child: Icon(Icons.person, color: AppColors.purple),
                ),
              ),
            ),
          ),
          if (unread > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1,
                ),
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4458),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          if (online)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VerifiedShield extends StatelessWidget {
  const _VerifiedShield();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      AppAssets.shield,
      width: 13,
      height: 13,
      colorFilter: const ColorFilter.mode(
        Color(0xFF3B82F6),
        BlendMode.srcIn,
      ),
    );
  }
}

class _EmptyConnections extends StatelessWidget {
  const _EmptyConnections({required this.filter});

  final ConnectionFilter filter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              filter == ConnectionFilter.requests
                  ? Icons.mark_email_read_outlined
                  : Icons.inventory_2_outlined,
              size: 26,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            filter == ConnectionFilter.requests
                ? 'No pending requests'
                : 'Nothing archived yet',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'This space updates as your connections grow.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
