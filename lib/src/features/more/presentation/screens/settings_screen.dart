import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SettingsHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionLabel(text: 'DISCOVERY PREFERENCES'),
                    _GroupCard(
                      rows: [
                        _RowConfig(
                          materialIcon: Icons.public_outlined,
                          title: 'Distance',
                          value: '25 miles',
                          onTap: () {},
                        ),
                        _RowConfig(
                          assetIcon: AppAssets.eye,
                          title: 'Age Range',
                          value: '21-45',
                          onTap: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const _SectionLabel(text: 'NOTIFICATIONS'),
                    _GroupCard(
                      rows: [
                        _RowConfig(
                          assetIcon: AppAssets.bell,
                          title: 'Push Notifications',
                          value: 'On',
                          onTap: () {},
                        ),
                        _RowConfig(
                          assetIcon: AppAssets.bell,
                          title: 'Email Notifications',
                          value: 'On',
                          onTap: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const _SectionLabel(text: 'PRIVACY'),
                    _GroupCard(
                      rows: [
                        _RowConfig(
                          assetIcon: AppAssets.lock,
                          title: 'Show Online Status',
                          value: 'On',
                          onTap: () {},
                        ),
                        _RowConfig(
                          assetIcon: AppAssets.eye,
                          title: 'Show Distance',
                          value: 'On',
                          onTap: () {},
                        ),
                        _RowConfig(
                          assetIcon: AppAssets.smartphone,
                          title: 'Connected Devices',
                          onTap: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _DeleteAccountTile(
                      onTap: () => _confirmDelete(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text('Delete account?'),
        content: const Text(
          'This is a front-end demo. No data is actually deleted.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4458),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 18, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0C132A),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Discovery preferences, notifications, privacy, and account controls',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _RowConfig {
  const _RowConfig({
    required this.title,
    required this.onTap,
    this.value,
    this.assetIcon,
    this.materialIcon,
  });

  final String title;
  final String? value;
  final String? assetIcon;
  final IconData? materialIcon;
  final VoidCallback onTap;
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.rows});

  final List<_RowConfig> rows;

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
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            _Row(config: rows[i]),
            if (i < rows.length - 1)
              const Divider(
                height: 1,
                color: AppColors.divider,
                indent: 16,
                endIndent: 16,
              ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.config});

  final _RowConfig config;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: config.onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Center(
                child: config.assetIcon != null
                    ? SvgPicture.asset(
                        config.assetIcon!,
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          AppColors.textPrimary,
                          BlendMode.srcIn,
                        ),
                      )
                    : Icon(
                        config.materialIcon ?? Icons.circle_outlined,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                config.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (config.value != null) ...[
              Text(
                config.value!,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteAccountTile extends StatelessWidget {
  const _DeleteAccountTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE4E8),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              AppAssets.trash,
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(
                Color(0xFFEF4458),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Delete Account',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEF4458),
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFFEF4458),
            ),
          ],
        ),
      ),
    );
  }
}
