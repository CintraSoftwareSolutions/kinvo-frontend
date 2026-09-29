import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/kinvo_colors.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../safety/data/trusted_contacts_repository.dart';
import '../../../safety/presentation/controllers/trusted_contacts_controllers.dart';
import '../../../safety/presentation/widgets/emergency_sheet.dart';
import '../widgets/settings_tile.dart';

/// Help when the user needs it: the emergency alert, the people it reaches,
/// and reporting someone.
class SafetyCenterScreen extends ConsumerWidget {
  const SafetyCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(trustedContactsProvider).value;
    final contactsLine = switch (contacts?.length) {
      null => 'Who Kinvo emails if you need help.',
      0 => 'Add who Kinvo should email if you need help.',
      final count => '$count of $maxTrustedContacts added.',
    };

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Safety Center',
              subtitle: 'Help when you need it',
              leading: HeaderBackButton(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                children: [
                  const _EmergencyCard(),
                  const SizedBox(height: 12),
                  SettingsTile(
                    icon: AppAssets.usersPink,
                    iconBg: context.colors.surfaceSoft,
                    iconColor: context.colors.textPrimary,
                    title: 'Trusted contacts',
                    subtitle: contactsLine,
                    onTap: () => context.push(AppRoutes.trustedContacts),
                  ),
                  const SizedBox(height: 8),
                  SettingsTile(
                    icon: AppAssets.flag,
                    iconBg: context.colors.surfaceSoft,
                    iconColor: context.colors.textPrimary,
                    title: 'Report a user',
                    subtitle: 'Tell us about someone who made you feel unsafe.',
                    onTap: () => context.push(AppRoutes.reportPath),
                  ),
                  const SizedBox(height: 8),
                  SettingsTile(
                    icon: AppAssets.mailIcon,
                    iconBg: context.colors.surfaceSoft,
                    iconColor: context.colors.textPrimary,
                    title: 'Support',
                    subtitle: 'Get help with your account or your safety.',
                    onTap: () => context.push(AppRoutes.support),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.dangerSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.sos_rounded, color: context.colors.danger, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Emergency help',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'If you are in danger, call your local emergency number first.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Kinvo can email your trusted contacts that you need help, with '
            'roughly where you are.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => showEmergencySheet(context),
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.danger,
              foregroundColor: context.colors.onAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Alert my trusted contacts'),
          ),
        ],
      ),
    );
  }
}
