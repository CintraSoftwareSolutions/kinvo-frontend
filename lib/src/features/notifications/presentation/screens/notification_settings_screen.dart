import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/demo/demo_mode.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/push/push_messaging.dart';
import '../../../../core/push/push_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/flow_widgets.dart';
import '../../../../core/widgets/page_header.dart';
import '../../domain/app_notification.dart';
import '../controllers/notifications_controllers.dart';

/// Whether this phone shows Kinvo's notifications, and which kinds arrive as
/// push notifications.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Notifications',
              subtitle: 'Choose what Kinvo tells you about',
              leading: HeaderBackButton(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                children: [
                  const _DeviceStatus(),
                  const SizedBox(height: 18),
                  const _SectionLabel('PUSH NOTIFICATIONS FOR'),
                  switch (preferences) {
                    AsyncValue(value: final preferences?) => _Categories(
                      preferences: preferences,
                    ),
                    AsyncValue(:final error?) => _LoadFailed(
                      message: error is ApiException
                          ? error.message
                          : 'Something went wrong. Please try again.',
                      onRetry: () =>
                          ref.invalidate(notificationPreferencesProvider),
                    ),
                    _ => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  },
                  const SizedBox(height: 12),
                  const Text(
                    'Everything still appears in your notifications list, '
                    'whatever arrives as a push.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
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

/// Whether this phone lets Kinvo show notifications at all.
class _DeviceStatus extends ConsumerWidget {
  const _DeviceStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(demoSessionProvider)) {
      return const _StatusCard(
        icon: Icons.notifications_off_outlined,
        title: 'Not in the demo',
        message: 'Push notifications arrive once you have an account.',
      );
    }
    if (!ref.watch(pushMessagingProvider).isAvailable) {
      return const _StatusCard(
        icon: Icons.notifications_off_outlined,
        title: 'Push notifications are unavailable',
        message:
            "This version of Kinvo can't receive push notifications. Your "
            'notifications list still has everything.',
      );
    }

    final permission = ref.watch(pushPermissionProvider);
    return switch (permission.value) {
      PushPermission.granted => const _StatusCard(
        icon: Icons.notifications_active_outlined,
        title: 'On for this phone',
        message: 'Choose below which ones you want.',
        positive: true,
      ),
      PushPermission.requestable => _StatusCard(
        icon: Icons.notifications_off_outlined,
        title: 'Off for this phone',
        message: "Turn them on so you don't miss a match or a message.",
        actionLabel: 'Turn on',
        onAction: () =>
            unawaited(ref.read(pushPermissionProvider.notifier).request()),
      ),
      PushPermission.blocked => _StatusCard(
        icon: Icons.notifications_off_outlined,
        title: "Off in your phone's settings",
        message:
            'Kinvo is not allowed to show notifications. You can allow them '
            "in your phone's settings.",
        actionLabel: 'Open settings',
        // The app's page in the phone's settings covers notifications too.
        onAction: () =>
            unawaited(ref.read(locationServiceProvider).openAppSettings()),
      ),
      null when permission.hasError => const _StatusCard(
        icon: Icons.notifications_off_outlined,
        title: 'Push notifications are unavailable',
        message:
            "Kinvo couldn't check this phone's notification settings. Your "
            'notifications list still has everything.',
      ),
      null => const SizedBox(height: 72),
    };
  }
}

class _Categories extends ConsumerWidget {
  const _Categories({required this.preferences});

  final List<NotificationPreference> preferences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = [
      for (final preference in preferences)
        if (preference.category != NotificationCategory.unknown) preference,
    ];

    // A Material rather than a decorated box, so the switches' ripples show
    // on the card instead of underneath it.
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Column(
        children: [
          for (final (index, preference) in shown.indexed) ...[
            _CategorySwitch(
              preference: preference,
              onChanged: preference.category.canBeSwitchedOff
                  ? (enabled) => _set(context, ref, preference, enabled)
                  : null,
            ),
            if (index < shown.length - 1)
              const Divider(height: 1, color: AppColors.divider, indent: 16),
          ],
        ],
      ),
    );
  }

  Future<void> _set(
    BuildContext context,
    WidgetRef ref,
    NotificationPreference preference,
    bool enabled,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref
        .read(notificationPreferencesProvider.notifier)
        .setPush(preference.category, enabled);
    if (error == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error)));
  }
}

class _CategorySwitch extends StatelessWidget {
  const _CategorySwitch({required this.preference, required this.onChanged});

  final NotificationPreference preference;

  /// `null` for a category that can't be switched off.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final (title, description) = switch (preference.category) {
      NotificationCategory.newMatch => (
        'New matches',
        'When someone likes you back',
      ),
      NotificationCategory.newLike => ('Likes', 'When someone likes you'),
      NotificationCategory.newMessage => (
        'Messages',
        'New messages from your matches',
      ),
      NotificationCategory.planUpdate => (
        'Plans',
        'Plans suggested, confirmed or cancelled, and reminders',
      ),
      NotificationCategory.call => ('Calls', 'When a match calls you'),
      NotificationCategory.safety => (
        'Safety',
        'Emergency alerts and updates on your reports. Always on.',
      ),
      NotificationCategory.moderation => (
        'Your profile',
        'Updates about your photos and verification',
      ),
      NotificationCategory.subscription => (
        'Subscription',
        'Changes to your plan',
      ),
      NotificationCategory.system || NotificationCategory.unknown => (
        'News from Kinvo',
        'Important updates about the app',
      ),
    };

    return SwitchListTile.adaptive(
      value: preference.pushEnabled,
      onChanged: onChanged,
      activeTrackColor: AppColors.purple,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        description,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.message,
    this.positive = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool positive;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: positive ? AppColors.greenSoft : AppColors.surfaceSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: positive ? AppColors.green : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 14),
            PrimaryActionButton(
              label: actionLabel,
              borderRadius: 999,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          PrimaryActionButton(
            label: 'Try again',
            borderRadius: 999,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
