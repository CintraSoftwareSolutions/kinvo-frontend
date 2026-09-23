import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/forms/form_errors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../settings/domain/user_settings.dart';
import '../../../settings/presentation/controllers/settings_controllers.dart';

/// How the app looks and moves: text size, movement, contrast and, when it is
/// painted, dark mode.
///
/// Everything here is kept on the server rather than on the phone, so someone
/// who needs larger text is set up that way on their next phone without having
/// to find this screen again.
class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

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
              title: 'Theme & accessibility',
              subtitle: 'Text size, movement, contrast and appearance',
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
        const SettingsSectionLabel('TEXT SIZE'),
        _TextSizeCard(settings: settings),
        const SizedBox(height: 22),
        const SettingsSectionLabel('MOVEMENT AND CONTRAST'),
        SettingsGroup(
          children: [
            SettingsSwitch(
              title: 'Reduce movement',
              description:
                  'Screens appear instead of sliding, and animations are kept '
                  'to a minimum.',
              value: settings.reduceMotion,
              onChanged: (on) => _change(
                context,
                ref,
                () => ref
                    .read(userSettingsProvider.notifier)
                    .change(reduceMotion: on),
              ),
            ),
            SettingsSwitch(
              title: 'Higher contrast',
              description:
                  'Stronger outlines and separators, where the app can draw '
                  'them.',
              value: settings.highContrast,
              onChanged: (on) => _change(
                context,
                ref,
                () => ref
                    .read(userSettingsProvider.notifier)
                    .change(highContrast: on),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const SettingsSectionLabel('APPEARANCE'),
        _AppearanceCard(settings: settings),
      ],
    );
  }

  /// Runs [change]. The control moves at once; if saving fails it moves back
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

/// A slider with the sentence above it drawn at the size being chosen.
class _TextSizeCard extends ConsumerStatefulWidget {
  const _TextSizeCard({required this.settings});

  final UserSettings settings;

  @override
  ConsumerState<_TextSizeCard> createState() => _TextSizeCardState();
}

class _TextSizeCardState extends ConsumerState<_TextSizeCard> {
  /// Where the slider is while it is being dragged. The saved value is only
  /// changed when the finger comes off, so a drag is one request, not fifty.
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final scale = _dragging ?? widget.settings.textScale;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Text this size is comfortable to read.',
            // Shown at the size being chosen, not the size in force, so the
            // slider previews itself while it is moved.
            textScaler: TextScaler.linear(
              scale / MediaQuery.textScalerOf(context).scale(1),
            ),
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('A', style: TextStyle(fontSize: 13)),
              Expanded(
                child: Slider(
                  value: scale,
                  min: UserSettings.minimumTextScale,
                  max: UserSettings.maximumTextScale,
                  // Eight steps across the range: enough to find a size, few
                  // enough that the difference between two is visible.
                  divisions: 8,
                  label: '${(scale * 100).round()}%',
                  activeColor: AppColors.purple,
                  onChanged: (value) => setState(() => _dragging = value),
                  onChangeEnd: _save,
                ),
              ),
              const Text('A', style: TextStyle(fontSize: 22)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save(double scale) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(userSettingsProvider.notifier).change(textScale: scale);
    } on ApiException catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(saveFailureMessage(error))));
    } finally {
      if (mounted) setState(() => _dragging = null);
    }
  }
}

/// Light, dark, or whatever the phone is set to.
class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard({required this.settings});

  final UserSettings settings;

  static const _labels = {
    AppThemeChoice.system: 'Match my phone',
    AppThemeChoice.light: 'Light',
    AppThemeChoice.dark: 'Dark',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RadioGroup<AppThemeChoice>(
          groupValue: settings.theme,
          onChanged: (picked) => _pick(context, ref, picked),
          child: SettingsGroup(
            children: [
              for (final choice in AppThemeChoice.values)
                RadioListTile<AppThemeChoice>(
                  value: choice,
                  activeColor: AppColors.purple,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: Text(
                    _labels[choice]!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Kinvo is only painted light at the moment, so choosing dark saves '
            'the choice and will apply as soon as the dark screens land.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  void _pick(BuildContext context, WidgetRef ref, AppThemeChoice? picked) {
    if (picked == null) return;
    final messenger = ScaffoldMessenger.of(context);
    unawaited(
      ref.read(userSettingsProvider.notifier).change(theme: picked).catchError((
        Object error,
      ) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(saveFailureMessage(error))));
      }, test: (error) => error is ApiException),
    );
  }
}
