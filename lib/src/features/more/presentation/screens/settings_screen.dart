import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ads/ads_controller.dart';
import '../../../../core/assets/app_assets.dart';
import '../../../../core/auth/auth_providers.dart';
import '../../../../core/auth/session_status.dart';
import '../../../../core/forms/form_errors.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/push/push_messaging.dart';
import '../../../../core/push/push_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/units/distance.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../auth/presentation/delete_account_dialog.dart';
import '../../../auth/presentation/log_out.dart';
import '../../../discovery/presentation/controllers/discovery_modes_controller.dart';
import '../../../discovery/presentation/widgets/filters_sheet.dart';
import '../../../discovery/presentation/widgets/mode_picker_sheet.dart';
import '../../../notifications/presentation/controllers/notifications_controllers.dart';
import '../../../settings/presentation/controllers/settings_controllers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAccount = ref.watch(sessionStatusProvider) is SignedIn;
    final pushPermission =
        hasAccount && ref.watch(pushMessagingProvider).isAvailable
        ? ref.watch(pushPermissionProvider).value
        : null;
    final settings = ref.watch(userSettingsProvider).value;
    // Where the law requires a way to change the answer given to Google's
    // consent message — the UK and the EEA — and only for accounts that see
    // ads at all.
    final adPrivacyChoices = ref.watch(adsProvider).privacyOptionsRequired;
    // Watched so the modes are ready when the filters are opened.
    final modes = ref.watch(discoveryModesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Settings',
              subtitle: 'Discovery, notifications, privacy and your account',
              leading: HeaderBackButton(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                children: [
                  const SettingsSectionLabel('DISCOVERY'),
                  SettingsGroup(
                    children: [
                      SettingsLink(
                        icon: Icons.tune_rounded,
                        title: 'Distance and age range',
                        description: 'Set for each mode',
                        onTap: modes.hasValue
                            ? () => unawaited(_openFilters(context, ref))
                            : null,
                      ),
                      SettingsLink(
                        icon: Icons.straighten_rounded,
                        title: 'Distance units',
                        value: switch (settings?.distanceUnit) {
                          DistanceUnit.miles => 'Miles',
                          DistanceUnit.kilometres => 'Kilometres',
                          null => null,
                        },
                        onTap: settings == null
                            ? null
                            : () => unawaited(
                                _chooseUnit(
                                  context,
                                  ref,
                                  settings.distanceUnit,
                                ),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const SettingsSectionLabel('NOTIFICATIONS'),
                  SettingsGroup(
                    children: [
                      SettingsLink(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notifications',
                        value: switch (pushPermission) {
                          PushPermission.granted => 'On',
                          PushPermission.requestable ||
                          PushPermission.blocked => 'Off',
                          null => null,
                        },
                        onTap: () =>
                            context.push(AppRoutes.notificationSettings),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const SettingsSectionLabel('PRIVACY'),
                  SettingsGroup(
                    children: [
                      SettingsLink(
                        icon: Icons.lock_outline_rounded,
                        title: 'Privacy',
                        description:
                            'What others see, taking a break, and your '
                            'devices',
                        value: (settings?.isOnBreak ?? false)
                            ? 'On a break'
                            : null,
                        onTap: () => context.push(AppRoutes.privacy),
                      ),
                      if (adPrivacyChoices)
                        SettingsLink(
                          icon: Icons.campaign_outlined,
                          title: 'Ad privacy choices',
                          description: 'Change what ads may use about you',
                          onTap: () => unawaited(
                            ref
                                .read(adConsentProvider.notifier)
                                .showPrivacyOptions(),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const SettingsSectionLabel('ACCOUNT'),
                  SettingsGroup(
                    children: [
                      SettingsLink(
                        icon: Icons.logout_rounded,
                        title: 'Log out',
                        onTap: () => unawaited(confirmLogOut(context, ref)),
                      ),
                    ],
                  ),
                  if (hasAccount) ...[
                    const SizedBox(height: 18),
                    _DeleteAccountTile(
                      onTap: () => unawaited(showDeleteAccountDialog(context)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens a mode's filters, asking which mode first when there are several.
  Future<void> _openFilters(BuildContext context, WidgetRef ref) async {
    final modes = ref.read(discoveryModesProvider).value ?? const [];
    if (modes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Switch a mode on first. Each mode has its own filters.',
          ),
        ),
      );
      return;
    }
    final active = ref.read(activeDiscoveryModeProvider).value ?? modes.first;
    final mode = modes.length == 1
        ? modes.single
        : await showModePickerSheet(
            context,
            modes: modes,
            activeMode: active.value,
          );
    if (mode == null || !context.mounted) return;
    await showFiltersSheet(context, mode);
  }

  Future<void> _chooseUnit(
    BuildContext context,
    WidgetRef ref,
    DistanceUnit current,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final unit = await showModalBottomSheet<DistanceUnit>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => _UnitSheet(current: current),
    );
    if (unit == null || unit == current) return;
    try {
      await ref.read(userSettingsProvider.notifier).change(distanceUnit: unit);
    } on ApiException catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(saveFailureMessage(error))));
    }
  }
}

class _UnitSheet extends StatelessWidget {
  const _UnitSheet({required this.current});

  final DistanceUnit current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Distance units',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'How far away people and places are shown, on every screen.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            RadioGroup<DistanceUnit>(
              groupValue: current,
              onChanged: (unit) => Navigator.of(context).pop(unit),
              child: const Column(
                children: [
                  RadioListTile<DistanceUnit>(
                    value: DistanceUnit.miles,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.purple,
                    title: Text('Miles'),
                  ),
                  RadioListTile<DistanceUnit>(
                    value: DistanceUnit.kilometres,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.purple,
                    title: Text('Kilometres'),
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

class _DeleteAccountTile extends StatelessWidget {
  const _DeleteAccountTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Delete account',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.dangerSoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              SvgPicture.asset(
                AppAssets.trash,
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(
                  AppColors.danger,
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
                    color: AppColors.danger,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.danger,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
