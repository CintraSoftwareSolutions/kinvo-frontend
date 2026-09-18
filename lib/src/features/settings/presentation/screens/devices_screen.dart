import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/forms/form_errors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/widgets/flow_widgets.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../domain/signed_in_device.dart';
import '../controllers/settings_controllers.dart';

/// Where the account is signed in, and signing other devices out.
class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(signedInDevicesProvider);
    final now = ref.watch(clockProvider)();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Signed-in devices',
              subtitle:
                  "If you don't recognise one, sign it out and change your "
                  'password.',
              leading: HeaderBackButton(),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () {
                  ref.invalidate(signedInDevicesProvider);
                  return ref.read(signedInDevicesProvider.future);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                  children: [
                    switch (devices) {
                      AsyncValue(value: final devices?) => _DeviceList(
                        devices: devices,
                        now: now,
                      ),
                      AsyncValue(:final error?) => LoadFailedCard(
                        message: saveFailureMessage(error),
                        onRetry: () => ref.invalidate(signedInDevicesProvider),
                      ),
                      _ => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    },
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

class _DeviceList extends ConsumerStatefulWidget {
  const _DeviceList({required this.devices, required this.now});

  final List<SignedInDevice> devices;
  final DateTime now;

  @override
  ConsumerState<_DeviceList> createState() => _DeviceListState();
}

class _DeviceListState extends ConsumerState<_DeviceList> {
  /// The device being signed out, or `'others'` for all the others.
  String? _signingOut;

  @override
  Widget build(BuildContext context) {
    final current = [
      for (final device in widget.devices)
        if (device.isCurrent) device,
    ];
    final others = [
      for (final device in widget.devices)
        if (!device.isCurrent) device,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (current.isNotEmpty) ...[
          const SettingsSectionLabel('THIS DEVICE'),
          SettingsGroup(
            children: [
              for (final device in current)
                _DeviceRow(device: device, now: widget.now),
            ],
          ),
          const SizedBox(height: 22),
        ],
        const SettingsSectionLabel('OTHER DEVICES'),
        if (others.isEmpty)
          const SurfaceCard(
            child: Text(
              "You're not signed in anywhere else.",
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          )
        else ...[
          SettingsGroup(
            children: [
              for (final device in others)
                _DeviceRow(
                  device: device,
                  now: widget.now,
                  signingOut: _signingOut == device.id,
                  onSignOut: _signingOut == null
                      ? () => unawaited(_signOut(device))
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 16),
          OutlineActionButton(
            label: others.length == 1
                ? 'Sign out the other device'
                : 'Sign out all ${others.length} other devices',
            onPressed: _signingOut == null
                ? () => unawaited(_signOutOthers(others.length))
                : null,
            foregroundColor: AppColors.danger,
            borderColor: AppColors.danger,
          ),
        ],
      ],
    );
  }

  Future<void> _signOut(SignedInDevice device) async {
    final confirmed = await _confirm(
      title: 'Sign out ${device.name}?',
      message:
          'Kinvo stops working on it straight away. Signing in again needs '
          'your password.',
    );
    if (!confirmed || !mounted) return;
    await _run(
      device.id,
      () => ref.read(signedInDevicesProvider.notifier).signOut(device.id),
      done: 'Signed out ${device.name}.',
    );
  }

  Future<void> _signOutOthers(int count) async {
    final confirmed = await _confirm(
      title: count == 1
          ? 'Sign out the other device?'
          : 'Sign out $count other devices?',
      message:
          "You'll stay signed in on this one. Kinvo stops working on the "
          'others straight away.',
    );
    if (!confirmed || !mounted) return;
    await _run(
      'others',
      () => ref.read(signedInDevicesProvider.notifier).signOutOthers(),
      done: count == 1 ? 'Signed out 1 device.' : 'Signed out $count devices.',
    );
  }

  Future<void> _run(
    String what,
    Future<void> Function() signOut, {
    required String done,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _signingOut = what);
    String message;
    try {
      await signOut();
      message = done;
    } on ApiException catch (error) {
      message = saveFailureMessage(error);
    } finally {
      if (mounted) setState(() => _signingOut = null);
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.now,
    this.signingOut = false,
    this.onSignOut,
  });

  final SignedInDevice device;
  final DateTime now;
  final bool signingOut;

  /// `null` for this device, which is signed out with Log out, and while
  /// another sign-out is under way.
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final details = [
      ?device.osVersion,
      if (device.appVersion case final version?) 'Kinvo $version',
      device.isCurrent
          ? 'Using now'
          : deviceActivityLabel(
              device.lastSeenAt,
              now: now,
              formatDay: MaterialLocalizations.of(context).formatShortMonthDay,
            ),
    ].join(' · ');

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      leading: Icon(
        device.platform == 'web'
            ? Icons.laptop_rounded
            : Icons.smartphone_rounded,
        color: AppColors.textPrimary,
      ),
      minLeadingWidth: 24,
      title: Text(
        device.name,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        details,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: device.isCurrent
          ? null
          : signingOut
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: onSignOut,
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Sign out'),
            ),
    );
  }
}

/// When a device was last used, as the list says it: "Active today",
/// "Active yesterday", "Active 3 days ago", or "Active on" a day that
/// [formatDay] names.
String deviceActivityLabel(
  DateTime lastSeenAt, {
  required DateTime now,
  required String Function(DateTime day) formatDay,
}) {
  final seen = lastSeenAt.toLocal();
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day);
  final days = today
      .difference(DateTime(seen.year, seen.month, seen.day))
      .inDays;
  if (days <= 0) return 'Active today';
  if (days == 1) return 'Active yesterday';
  if (days < 7) return 'Active $days days ago';
  return 'Active on ${formatDay(seen)}';
}
