import 'package:flutter/material.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/page_header.dart';
import '../widgets/settings_tile.dart';

class SafetyCenterScreen extends StatefulWidget {
  const SafetyCenterScreen({super.key});

  @override
  State<SafetyCenterScreen> createState() => _SafetyCenterScreenState();
}

class _SafetyCenterScreenState extends State<SafetyCenterScreen> {
  bool _liveShare = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Safety Center',
              subtitle: 'Live status, reporting, and trusted-contact tools',
              leading: HeaderBackButton(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SettingsTile(
                      title: 'Live share status',
                      subtitle:
                          'Trusted contacts can receive your current location during a plan.',
                      trailing: OnOffToggle(
                        value: _liveShare,
                        onChanged: (v) => setState(() => _liveShare = v),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SettingsTile(
                      icon: AppAssets.usersPink,
                      iconBg: AppColors.surfaceSoft,
                      iconColor: AppColors.textPrimary,
                      title: 'Trusted contacts',
                      subtitle: 'Add or remove who gets alerted first.',
                      onTap: () => Navigator.of(context)
                          .pushNamed(AppRoutes.trustedContacts),
                    ),
                    const SizedBox(height: 8),
                    SettingsTile(
                      icon: AppAssets.flag,
                      iconBg: AppColors.surfaceSoft,
                      iconColor: AppColors.textPrimary,
                      title: 'Report a user',
                      subtitle: 'Create a local report with category and notes.',
                      onTap: () =>
                          Navigator.of(context).pushNamed(AppRoutes.report),
                    ),
                    const SizedBox(height: 8),
                    SettingsTile(
                      icon: AppAssets.phone,
                      iconBg: AppColors.surfaceSoft,
                      iconColor: AppColors.textPrimary,
                      title: 'Emergency help',
                      subtitle:
                          'Fast path to call emergency services or your contact.',
                      onTap: () {},
                    ),
                    const SizedBox(height: 8),
                    SettingsTile(
                      icon: AppAssets.mailIcon,
                      iconBg: AppColors.surfaceSoft,
                      iconColor: AppColors.textPrimary,
                      title: 'Support mail',
                      subtitle:
                          'Open the support action for account or safety help.',
                      onTap: () =>
                          Navigator.of(context).pushNamed(AppRoutes.support),
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
