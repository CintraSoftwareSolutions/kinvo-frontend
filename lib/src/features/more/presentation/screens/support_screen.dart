import 'package:flutter/material.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/page_header.dart';
import '../widgets/settings_tile.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Support & guidelines',
              subtitle: 'Help, policy, and escalation entry points',
              leading: HeaderBackButton(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.lightbulb_outline,
                              size: 18,
                              color: Color(0xFFD97706),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Resolve issues without leaving the app',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Help articles, trust policies, and support escalation are grouped together for faster recovery.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    height: 1.4,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SettingsTile(
                      icon: AppAssets.helpCircle,
                      iconBg: AppColors.surfaceSoft,
                      iconColor: AppColors.textPrimary,
                      title: 'Help center',
                      subtitle:
                          'Account setup, matching, billing, and troubleshooting articles.',
                      onTap: () {},
                    ),
                    const SizedBox(height: 8),
                    SettingsTile(
                      icon: AppAssets.shield,
                      iconBg: AppColors.surfaceSoft,
                      iconColor: AppColors.textPrimary,
                      title: 'Community guidelines',
                      subtitle:
                          'Behavior expectations, moderation standards, and penalties.',
                      onTap: () {},
                    ),
                    const SizedBox(height: 8),
                    SettingsTile(
                      icon: AppAssets.lock,
                      iconBg: AppColors.surfaceSoft,
                      iconColor: AppColors.textPrimary,
                      title: 'Terms & privacy',
                      subtitle:
                          'Policies for data handling, subscriptions, and legal agreements.',
                      onTap: () {},
                    ),
                    const SizedBox(height: 8),
                    SettingsTile(
                      icon: AppAssets.triangleAlert,
                      iconBg: AppColors.surfaceSoft,
                      iconColor: AppColors.textPrimary,
                      title: 'Safety escalation',
                      subtitle:
                          'Fast access to emergency reporting and trusted-contact workflows.',
                      onTap: () {},
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Opening support mail draft...'),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Email support'),
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
