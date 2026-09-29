import 'package:flutter/material.dart';

import '../theme/kinvo_colors.dart';
import 'flow_widgets.dart';

/// The small capitals above a group of settings, such as "WHAT OTHERS SEE".
class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: context.colors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Settings rows on one white card, with lines between them.
///
/// A [Material] rather than a decorated box, so the rows' ripples show on the
/// card instead of underneath it.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: context.colors.divider),
      ),
      child: Column(
        children: [
          for (final (index, child) in children.indexed) ...[
            child,
            if (index < children.length - 1)
              Divider(height: 1, color: context.colors.divider, indent: 16),
          ],
        ],
      ),
    );
  }
}

/// A switch in a [SettingsGroup].
class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String title;
  final String description;
  final bool value;

  /// `null` while the switch can't be changed.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeTrackColor: context.colors.purple,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: context.colors.textPrimary,
        ),
      ),
      subtitle: Text(
        description,
        style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
      ),
    );
  }
}

/// A row in a [SettingsGroup] that opens something or chooses a value.
class SettingsLink extends StatelessWidget {
  const SettingsLink({
    required this.icon,
    required this.title,
    required this.onTap,
    this.description,
    this.value,
    this.danger = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? description;

  /// The current choice, shown at the end of the row.
  final String? value;
  final VoidCallback? onTap;

  /// For rows that sign out or delete.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? context.colors.danger : context.colors.textPrimary;
    final value = this.value;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, size: 22, color: color),
      minLeadingWidth: 24,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      subtitle: description == null
          ? null
          : Text(
              description!,
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textMuted,
                ),
              ),
            ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: danger ? context.colors.danger : context.colors.textMuted,
            ),
          ],
        ],
      ),
    );
  }
}

/// Said in place of something that couldn't load, with a way to try again.
class LoadFailedCard extends StatelessWidget {
  const LoadFailedCard({
    required this.message,
    required this.onRetry,
    super.key,
  });

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
            style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
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
