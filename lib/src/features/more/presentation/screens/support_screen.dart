import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/config/server_config.dart';
import '../../../../core/config/server_config_providers.dart';
import '../../../../core/links/external_links.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/page_header.dart';
import '../widgets/settings_tile.dart';

/// Help, the rules, and the way to safety tools.
///
/// Every row leads somewhere real. The pages and the support address come
/// from the server, and a row whose page Kinvo hasn't published yet isn't
/// shown at all, rather than shown and doing nothing.
class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(supportLinksProvider);
    final pages = _pagesOf(links);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Support & guidelines',
              subtitle: 'Help, the rules, and safety',
              leading: HeaderBackButton(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SettingsTile(
                      icon: AppAssets.triangleAlert,
                      iconBg: AppColors.surfaceSoft,
                      iconColor: AppColors.textPrimary,
                      title: 'Safety Center',
                      subtitle:
                          'Emergency alert, trusted contacts, and reporting '
                          'someone.',
                      onTap: () => context.push(AppRoutes.safetyCenter),
                    ),
                    for (final page in pages) ...[
                      const SizedBox(height: 8),
                      SettingsTile(
                        icon: page.icon,
                        iconBg: AppColors.surfaceSoft,
                        iconColor: AppColors.textPrimary,
                        title: page.title,
                        subtitle: page.subtitle,
                        onTap: () => _openPage(context, ref, page.address),
                      ),
                    ],
                    if (links.email case final address?) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () =>
                              _writeToSupport(context, ref, address),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<_Page> _pagesOf(SupportLinks links) {
    return [
      if (links.helpCentre case final address?)
        _Page(
          icon: AppAssets.helpCircle,
          title: 'Help centre',
          subtitle: 'Answers about your account, matching and plans.',
          address: address,
        ),
      if (links.guidelines case final address?)
        _Page(
          icon: AppAssets.shield,
          title: 'Community guidelines',
          subtitle: "What's allowed on Kinvo, and what happens if it isn't.",
          address: address,
        ),
      if (links.terms case final address?)
        _Page(
          icon: AppAssets.lock,
          title: 'Terms of service',
          subtitle: 'The agreement you make by using Kinvo.',
          address: address,
        ),
      if (links.privacy case final address?)
        _Page(
          icon: AppAssets.lock,
          title: 'Privacy policy',
          subtitle: 'What Kinvo keeps about you, and why.',
          address: address,
        ),
    ];
  }

  static Future<void> _openPage(
    BuildContext context,
    WidgetRef ref,
    Uri address,
  ) async {
    final opened = await ref.read(externalLinksProvider).openPage(address);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Nothing on this phone can open it.')),
        );
    }
  }

  /// Starts an email to support. A phone with no mail app is shown the
  /// address to copy instead, so asking for help never dead-ends.
  static Future<void> _writeToSupport(
    BuildContext context,
    WidgetRef ref,
    String address,
  ) async {
    final opened = await ref
        .read(externalLinksProvider)
        .writeEmail(to: address, subject: 'Kinvo support');
    if (opened || !context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Email support'),
        content: Text("There's no mail app on this phone. Write to $address."),
        actions: [
          TextButton(
            onPressed: () {
              unawaited(Clipboard.setData(ClipboardData(text: address)));
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Copy address'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// One of Kinvo's published pages.
final class _Page {
  const _Page({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.address,
  });

  final String icon;
  final String title;
  final String subtitle;
  final Uri address;
}
