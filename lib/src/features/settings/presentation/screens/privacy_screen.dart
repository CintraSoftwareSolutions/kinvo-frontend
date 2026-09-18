import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/forms/form_errors.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/flow_widgets.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../domain/user_settings.dart';
import '../controllers/settings_controllers.dart';
import '../widgets/take_break_sheet.dart';

/// Who sees what, taking a break from Discover, and where the account is
/// signed in.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(userSettingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Privacy',
              subtitle: 'What others see, taking a break, and your devices',
              leading: HeaderBackButton(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                children: [
                  switch (settings) {
                    AsyncValue(value: final settings?) => _Settings(
                      settings: settings,
                    ),
                    AsyncValue(:final error?) => LoadFailedCard(
                      message: saveFailureMessage(error),
                      onRetry: () => ref.invalidate(userSettingsProvider),
                    ),
                    _ => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  },
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Settings extends ConsumerWidget {
  const _Settings({required this.settings});

  final UserSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BreakCard(settings: settings),
        const SizedBox(height: 22),
        const SettingsSectionLabel('WHAT OTHERS SEE'),
        SettingsGroup(
          children: [
            SettingsSwitch(
              title: 'Show my distance',
              description:
                  'People see roughly how far away you are, never where you '
                  'are.',
              value: settings.showDistance,
              onChanged: (show) => _change(
                context,
                ref,
                () => ref
                    .read(userSettingsProvider.notifier)
                    .change(showDistance: show),
              ),
            ),
            SettingsSwitch(
              title: "Show when I'm active",
              description:
                  "Your matches see when you're online or were last active. "
                  "You still see theirs.",
              value: settings.showLastActive,
              onChanged: (show) => _change(
                context,
                ref,
                () => ref
                    .read(userSettingsProvider.notifier)
                    .change(showLastActive: show),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const SettingsSectionLabel('SECURITY'),
        SettingsGroup(
          children: [
            SettingsLink(
              icon: Icons.devices_outlined,
              title: 'Signed-in devices',
              description: "See where you're signed in, and sign out",
              onTap: () => context.push(AppRoutes.devices),
            ),
          ],
        ),
      ],
    );
  }

  /// Runs [change]. The switch flips at once; if saving fails it flips back
  /// and the reason is shown.
  void _change(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() change,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    unawaited(
      change().catchError((Object error) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(saveFailureMessage(error))));
      }, test: (error) => error is ApiException),
    );
  }
}

/// Taking a break from Discover, or coming back from one.
class BreakCard extends ConsumerStatefulWidget {
  const BreakCard({required this.settings, super.key});

  final UserSettings settings;

  @override
  ConsumerState<BreakCard> createState() => _BreakCardState();
}

class _BreakCardState extends ConsumerState<BreakCard> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final snooze = widget.settings.snooze;
    final onBreak = snooze != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: onBreak ? AppColors.purpleSoft : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: onBreak
              ? AppColors.purple.withValues(alpha: 0.3)
              : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                onBreak
                    ? Icons.pause_circle_rounded
                    : Icons.pause_circle_outline_rounded,
                color: AppColors.purple,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    onBreak ? "You're taking a break" : 'Take a break',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            onBreak
                ? '${_until(context, snooze.endsAt)} Your matches and chats '
                      'carry on as normal.'
                : 'Hide your profile from Discover for a while. Your matches '
                      'and chats carry on as normal.',
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          if (onBreak)
            PrimaryActionButton(
              label: 'Come back now',
              borderRadius: 999,
              loading: _saving,
              onPressed: _endBreak,
            )
          else
            OutlineActionButton(
              label: 'Take a break',
              onPressed: _saving ? null : _takeBreak,
              foregroundColor: AppColors.purple,
              borderColor: AppColors.purple,
            ),
        ],
      ),
    );
  }

  static String _until(BuildContext context, DateTime? endsAt) {
    if (endsAt == null) {
      return 'Nobody new sees you in Discover until you come back.';
    }
    final localizations = MaterialLocalizations.of(context);
    final local = endsAt.toLocal();
    final day = localizations.formatMediumDate(local);
    final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return 'Nobody new sees you in Discover until $day, $time.';
  }

  Future<void> _takeBreak() async {
    final length = await showTakeBreakSheet(context);
    if (length == null || !mounted) return;
    await _save(
      () => ref
          .read(userSettingsProvider.notifier)
          .takeBreak(duration: length.duration),
    );
  }

  Future<void> _endBreak() {
    return _save(() => ref.read(userSettingsProvider.notifier).endBreak());
  }

  Future<void> _save(Future<void> Function() save) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await save();
    } on ApiException catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(saveFailureMessage(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
