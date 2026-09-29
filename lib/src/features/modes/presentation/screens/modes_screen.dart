import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/kinvo_colors.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../domain/mode_choice.dart';
import '../controllers/user_modes_controller.dart';
import '../mode_change_feedback.dart';
import '../mode_presentation.dart';

/// Your modes: switch modes on and off, and choose the main one — the one
/// the app opens in. The plan's limit on modes at once is said up front.
///
/// Every rule is the server's: the limit, Cuddle's verified identity, and
/// which mode becomes the main one when the main one is switched off. The
/// only rule of the app's own is that the last mode stays on.
class ModesScreen extends ConsumerStatefulWidget {
  const ModesScreen({super.key});

  @override
  ConsumerState<ModesScreen> createState() => _ModesScreenState();
}

class _ModesScreenState extends ConsumerState<ModesScreen> {
  /// The mode whose change is saving, so its row says so and the rest wait.
  String? _changing;

  @override
  Widget build(BuildContext context) {
    final choices = ref.watch(modeChoicesProvider);
    final modes = ref.watch(userModesProvider).value;
    final list = choices.value;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Your modes',
              subtitle: 'Who you meet, and where',
              leading: HeaderBackButton(),
            ),
            Expanded(
              child: list != null
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                      children: [
                        if (modes != null)
                          _PlanNote(
                            enabled: modes.enabledModes.length,
                            max: modes.maxEnabled,
                          ),
                        const SizedBox(height: 14),
                        for (final choice in list) ...[
                          _ModeTile(
                            choice: choice,
                            saving: _changing == choice.value,
                            locked: _changing != null,
                            onSwitch: (on) => unawaited(_switch(choice, on)),
                            onMakeMain: () => unawaited(_makeMain(choice)),
                            onVerify: () => unawaited(
                              offerVerification(
                                context,
                                modeLabel: choice.label,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    )
                  : choices.hasError
                  ? Padding(
                      padding: const EdgeInsets.all(18),
                      child: LoadFailedCard(
                        message: switch (choices.error) {
                          final ApiException error => error.message,
                          _ => "Your modes didn't load.",
                        },
                        onRetry: () => ref.invalidate(userModesProvider),
                      ),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switch(ModeChoice choice, bool on) async {
    final controller = ref.read(userModesProvider.notifier);
    setState(() => _changing = choice.value);
    final outcome = on
        ? await controller.turnOn(choice.value)
        : await controller.turnOff(choice.value);
    if (!mounted) return;
    setState(() => _changing = null);
    await showModeChangeOutcome(
      context,
      outcome,
      modeLabel: choice.label,
      done: on ? '${choice.label} is on.' : '${choice.label} is off.',
    );
  }

  Future<void> _makeMain(ModeChoice choice) async {
    final controller = ref.read(userModesProvider.notifier);
    setState(() => _changing = choice.value);
    final outcome = await controller.makeMain(choice.value);
    if (!mounted) return;
    setState(() => _changing = null);
    await showModeChangeOutcome(
      context,
      outcome,
      modeLabel: choice.label,
      done: '${choice.label} is your main mode. Kinvo opens in it.',
    );
  }
}

/// How many modes are on, and how many the plan allows at once.
class _PlanNote extends StatelessWidget {
  const _PlanNote({required this.enabled, required this.max});

  final int enabled;

  /// The plan's limit, or `null` for no limit.
  final int? max;

  @override
  Widget build(BuildContext context) {
    final limit = max;
    final full = limit != null && enabled >= limit;
    final text = limit == null
        ? 'Your plan includes every mode, as many at once as you like.'
        : full
        ? '$enabled of $limit on: your plan allows $limit modes at a time. '
              'Switch one off to turn on another, or upgrade for more.'
        : '$enabled of $limit on: your plan allows $limit modes at a time.';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: context.colors.purpleSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.layers_outlined, size: 20, color: context.colors.purple),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: context.colors.textPrimary,
              ),
            ),
          ),
          if (full)
            TextButton(
              onPressed: () => context.push(AppRoutes.premium),
              style: TextButton.styleFrom(
                foregroundColor: context.colors.purple,
              ),
              child: const Text('See plans'),
            ),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.choice,
    required this.saving,
    required this.locked,
    required this.onSwitch,
    required this.onMakeMain,
    required this.onVerify,
  });

  final ModeChoice choice;

  /// This mode's change is saving.
  final bool saving;

  /// A change, this one or another, is saving, so nothing else can start.
  final bool locked;

  final ValueChanged<bool> onSwitch;
  final VoidCallback onMakeMain;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final modeTint = context.colors.mode(choice.value);
    final needsVerifying = !choice.isOn && choice.needsVerification;
    final description = choice.isUnavailable
        ? "This mode isn't available to you yet."
        : needsVerifying
        ? 'Verify your identity to use this mode.'
        : choice.description;

    return Material(
      color: context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.colors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Only a locked mode is a tap target as a whole; the others have
        // their switch.
        onTap: needsVerifying ? onVerify : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MergeSemantics(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: choice.isOn
                            ? modeTint.soft
                            : context.colors.surfaceSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          modeIconAsset(choice.value),
                          width: 18,
                          height: 18,
                          excludeFromSemantics: true,
                          colorFilter: ColorFilter.mode(
                            modeTint.color,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  choice.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.textPrimary,
                                  ),
                                ),
                              ),
                              if (choice.isMain) ...[
                                const SizedBox(width: 8),
                                const _MainBadge(),
                              ],
                            ],
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (saving)
                      const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (needsVerifying || choice.isUnavailable)
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Icon(
                          Icons.lock_outline_rounded,
                          size: 20,
                          color: context.colors.textMuted,
                        ),
                      )
                    else
                      Switch(
                        value: choice.isOn,
                        activeTrackColor: context.colors.purple,
                        onChanged: locked ? null : onSwitch,
                      ),
                  ],
                ),
              ),
              if (choice.isOn && !choice.isMain)
                Padding(
                  padding: const EdgeInsets.only(left: 44),
                  child: TextButton(
                    onPressed: locked ? null : onMakeMain,
                    style: TextButton.styleFrom(
                      foregroundColor: context.colors.purple,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text('Make ${choice.label} my main mode'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MainBadge extends StatelessWidget {
  const _MainBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: context.colors.purple,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Main',
        style: TextStyle(
          color: context.colors.onAccent,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
