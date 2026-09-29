import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/kinvo_colors.dart';
import '../../../modes/domain/mode_choice.dart';
import '../../../modes/presentation/mode_presentation.dart';

/// What the user chose in the mode switcher.
@immutable
sealed class ModeSwitch {
  const ModeSwitch();
}

/// Show [mode], which is already on.
final class ShowMode extends ModeSwitch {
  const ShowMode(this.mode);

  final String mode;
}

/// Switch [choice] on, then show it.
final class TurnOnMode extends ModeSwitch {
  const TurnOnMode(this.choice);

  final ModeChoice choice;
}

/// [choice] needs a verified identity first.
final class VerifyForMode extends ModeSwitch {
  const VerifyForMode(this.choice);

  final ModeChoice choice;
}

/// Open Your modes, to switch modes off or change the main one.
final class ManageModes extends ModeSwitch {
  const ManageModes();
}

/// Every mode, to show one that's on or switch another on. [showing] is the
/// mode Discover shows now. Resolves to what was chosen, or `null` if the
/// sheet is dismissed.
Future<ModeSwitch?> showModeSwitcherSheet(
  BuildContext context, {
  required List<ModeChoice> choices,
  required String showing,
}) {
  return showModalBottomSheet<ModeSwitch>(
    context: context,
    backgroundColor: context.colors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ModeSwitcherSheet(choices: choices, showing: showing),
  );
}

class ModeSwitcherSheet extends StatelessWidget {
  const ModeSwitcherSheet({
    required this.choices,
    required this.showing,
    super.key,
  });

  final List<ModeChoice> choices;

  /// The API name of the mode Discover shows now.
  final String showing;

  @override
  Widget build(BuildContext context) {
    void choose(ModeSwitch choice) => Navigator.of(context).pop(choice);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.handle,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Mode',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Each mode has its own deck, filters and matches.',
              style: TextStyle(
                fontSize: 12.5,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final choice in choices)
                      _ChoiceRow(
                        choice: choice,
                        showing: choice.value == showing,
                        onTap: switch (choice) {
                          ModeChoice(isOn: true) => () => choose(
                            ShowMode(choice.value),
                          ),
                          ModeChoice(canEnable: true) => () => choose(
                            TurnOnMode(choice),
                          ),
                          ModeChoice(needsVerification: true) => () => choose(
                            VerifyForMode(choice),
                          ),
                          _ => null,
                        },
                      ),
                  ],
                ),
              ),
            ),
            Center(
              child: TextButton.icon(
                onPressed: () => choose(const ManageModes()),
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Manage your modes'),
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.purple,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.choice,
    required this.showing,
    required this.onTap,
  });

  final ModeChoice choice;
  final bool showing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final modeTint = context.colors.mode(choice.value);
    final dimmed = !choice.isOn && !choice.canEnable;
    final hint = showing
        ? 'Showing now'
        : choice.isOn
        ? (choice.isMain ? 'Main mode' : null)
        : choice.canEnable
        ? 'Off. Double tap to turn on'
        : choice.needsVerification
        ? 'Needs a verified identity'
        : 'Not available';

    return Semantics(
      button: onTap != null,
      selected: showing,
      label: choice.label,
      hint: hint,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: dimmed ? 0.55 : 1,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: showing
                  ? context.colors.purple
                  : context.colors.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: showing
                        ? context.colors.onAccent.withValues(alpha: 0.18)
                        : choice.isOn
                        ? modeTint.soft
                        : context.colors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      modeIconAsset(choice.value),
                      width: 16,
                      height: 16,
                      colorFilter: ColorFilter.mode(
                        showing ? context.colors.onAccent : modeTint.color,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    choice.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: showing
                          ? context.colors.onAccent
                          : choice.isOn
                          ? context.colors.textPrimary
                          : context.colors.textSecondary,
                    ),
                  ),
                ),
                _Trailing(choice: choice, showing: showing),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the row's right-hand side says: showing now, the main mode, how to
/// switch it on, or why it can't be yet.
class _Trailing extends StatelessWidget {
  const _Trailing({required this.choice, required this.showing});

  final ModeChoice choice;
  final bool showing;

  @override
  Widget build(BuildContext context) {
    if (showing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: context.colors.onAccent.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'ACTIVE',
          style: TextStyle(
            color: context.colors.onAccent,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );
    }
    if (choice.isOn) {
      return choice.isMain
          ? Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                'MAIN',
                style: TextStyle(
                  color: context.colors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            )
          : const SizedBox.shrink();
    }
    if (choice.canEnable) {
      return Text(
        'Turn on',
        style: TextStyle(
          color: context.colors.purple,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 16,
          color: context.colors.textMuted,
        ),
        if (choice.needsVerification) ...[
          const SizedBox(width: 4),
          Text(
            'Verify',
            style: TextStyle(
              color: context.colors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}
