import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets/app_assets.dart';
import '../theme/app_colors.dart';

class AppBackButton extends StatelessWidget {
  const AppBackButton({
    this.onTap,
    this.size = 36,
    this.iconSize = 16,
    super.key,
  });

  final VoidCallback? onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.divider),
        ),
        child: Center(
          child: SvgPicture.asset(
            AppAssets.arrowBack,
            width: iconSize,
            height: iconSize,
          ),
        ),
      ),
    );
  }
}

class FlowPageLayout extends StatelessWidget {
  const FlowPageLayout({
    required this.badgeText,
    required this.title,
    required this.subtitle,
    required this.content,
    this.badgeAsset,
    this.badgeIcon,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 24),
    this.backButton,
    this.backButtonSpacing = 18,
    this.badgeSpacing = 18,
    this.titleSpacing = 10,
    this.subtitleSpacing = 18,
    this.titleStyle,
    this.subtitleStyle,
    super.key,
  });

  final String badgeText;
  final String title;
  final String subtitle;
  final Widget content;
  final String? badgeAsset;
  final IconData? badgeIcon;
  final EdgeInsetsGeometry padding;
  final Widget? backButton;
  final double backButtonSpacing;
  final double badgeSpacing;
  final double titleSpacing;
  final double subtitleSpacing;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          backButton ?? const AppBackButton(),
          SizedBox(height: backButtonSpacing),
          AppBadge(label: badgeText, assetName: badgeAsset, icon: badgeIcon),
          SizedBox(height: badgeSpacing),
          Text(
            title,
            style:
                titleStyle ??
                Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 30,
                  height: 1.1,
                  letterSpacing: -0.8,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
          ),
          SizedBox(height: titleSpacing),
          Text(
            subtitle,
            style:
                subtitleStyle ??
                Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 13,
                  height: 1.55,
                  color: AppColors.textSecondary,
                ),
          ),
          SizedBox(height: subtitleSpacing),
          content,
        ],
      ),
    );
  }
}

class AppBadge extends StatelessWidget {
  const AppBadge({
    required this.label,
    this.assetName,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.iconSize = 12,
    this.gap = 6,
    this.radius = 999,
    this.textStyle,
    super.key,
  });

  final String label;
  final String? assetName;
  final IconData? icon;
  final EdgeInsetsGeometry padding;
  final double iconSize;
  final double gap;
  final double radius;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (assetName != null) ...[
            SvgPicture.asset(
              assetName!,
              width: iconSize,
              height: iconSize,
              colorFilter: const ColorFilter.mode(
                AppColors.purple,
                BlendMode.srcIn,
              ),
            ),
            SizedBox(width: gap),
          ],
          if (icon != null) ...[
            Icon(icon, size: iconSize + 2, color: AppColors.purple),
            SizedBox(width: gap),
          ],
          Text(
            label,
            style:
                textStyle ??
                Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.purple,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = 22,
    this.backgroundColor,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0C132A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    required this.title,
    required this.description,
    this.assetName = AppAssets.shield,
    this.iconColor = AppColors.blue,
    this.backgroundColor = AppColors.surfaceSoft,
    this.borderRadius = 14,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 12),
    this.iconSize = 16,
    this.titleStyle,
    this.descriptionStyle,
    super.key,
  });

  final String title;
  final String description;
  final String assetName;
  final Color? iconColor;
  final Color backgroundColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double iconSize;
  final TextStyle? titleStyle;
  final TextStyle? descriptionStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: .2),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: SvgPicture.asset(
              assetName,
              width: iconSize,
              height: iconSize,
              colorFilter: iconColor == null
                  ? null
                  : ColorFilter.mode(iconColor!, BlendMode.srcIn),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      titleStyle ??
                      Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style:
                      descriptionStyle ??
                      Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 11.5,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppInputCard extends StatelessWidget {
  const AppInputCard({
    required this.label,
    required this.value,
    required this.onChanged,
    this.assetName,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.hintText,
    this.readOnly = false,
    this.enabled = true,
    this.errorText,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.trailing,
    this.padding = _InputCard.defaultPadding,
    this.borderRadius = _InputCard.defaultBorderRadius,
    this.labelStyle,
    this.valueStyle,
    this.iconSize = 14,
    this.iconGap = 8,
    super.key,
  });

  final String label;

  /// The field's starting text. Later edits are reported to [onChanged].
  final String value;
  final ValueChanged<String> onChanged;
  final String? assetName;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int maxLines;

  /// With [maxLines], lets the field grow from this many lines as text is
  /// entered.
  final int? minLines;

  /// Shown in the empty field.
  final String? hintText;
  final bool readOnly;
  final bool enabled;

  /// Shown under the card, which is outlined while there's an error.
  final String? errorText;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;
  final bool autocorrect;
  final bool enableSuggestions;

  /// Shown at the end of the card, such as a button that reveals a password.
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final double iconSize;
  final double iconGap;

  @override
  Widget build(BuildContext context) {
    return _FieldWithError(
      errorText: errorText,
      child: _InputCard(
        label: label,
        hasError: errorText != null,
        padding: padding,
        borderRadius: borderRadius,
        labelStyle: labelStyle,
        trailing: trailing,
        value: Row(
          children: [
            if (assetName != null) ...[
              SvgPicture.asset(
                assetName!,
                width: iconSize,
                height: iconSize,
                colorFilter: const ColorFilter.mode(
                  AppColors.textSecondary,
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(width: iconGap),
            ],
            Expanded(
              child: TextFormField(
                initialValue: value,
                onChanged: onChanged,
                onFieldSubmitted: onSubmitted,
                readOnly: readOnly,
                enabled: enabled,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
                textCapitalization: textCapitalization,
                autocorrect: autocorrect,
                enableSuggestions: enableSuggestions,
                autofillHints: autofillHints,
                obscureText: obscureText,
                maxLines: maxLines,
                minLines: minLines,
                style: valueStyle ?? _inputValueStyle(context),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: hintText,
                  hintStyle: _inputValueStyle(context)?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An [AppInputCard] for a password, with a button that shows what was typed.
class PasswordInputCard extends StatefulWidget {
  const PasswordInputCard({
    required this.label,
    required this.onChanged,
    this.value = '',
    this.isNewPassword = false,
    this.errorText,
    this.enabled = true,
    this.textInputAction,
    this.onSubmitted,
    super.key,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  /// Whether a password is being chosen rather than entered, so password
  /// managers offer to create one instead of filling in a saved one.
  final bool isNewPassword;
  final String? errorText;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordInputCard> createState() => _PasswordInputCardState();
}

class _PasswordInputCardState extends State<PasswordInputCard> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return AppInputCard(
      label: widget.label,
      value: widget.value,
      onChanged: widget.onChanged,
      assetName: AppAssets.lock,
      obscureText: _hidden,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: [
        widget.isNewPassword
            ? AutofillHints.newPassword
            : AutofillHints.password,
      ],
      errorText: widget.errorText,
      enabled: widget.enabled,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      trailing: IconButton(
        onPressed: () => setState(() => _hidden = !_hidden),
        tooltip: _hidden ? 'Show password' : 'Hide password',
        icon: Icon(
          _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
        iconSize: 18,
        color: AppColors.textSecondary,
        padding: EdgeInsets.zero,
        // No taller than the label and value beside it, so this card is the
        // same height as the others.
        constraints: const BoxConstraints.tightFor(width: 40, height: 34),
      ),
    );
  }
}

/// A card that looks like [AppInputCard] for a value chosen from a picker,
/// such as a date.
class AppPickerCard extends StatelessWidget {
  const AppPickerCard({
    required this.label,
    required this.placeholder,
    required this.onTap,
    this.value,
    this.icon,
    this.errorText,
    this.enabled = true,
    super.key,
  });

  final String label;

  /// The chosen value, or `null` to show [placeholder].
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final IconData? icon;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    final icon = this.icon;
    final valueStyle = _inputValueStyle(context);

    return _FieldWithError(
      errorText: errorText,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        value: value ?? placeholder,
        onTap: enabled ? onTap : null,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          behavior: HitTestBehavior.opaque,
          child: _InputCard(
            label: label,
            hasError: errorText != null,
            value: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    value ?? placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: value == null
                        ? valueStyle?.copyWith(color: AppColors.textMuted)
                        : valueStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The rounded, labelled card behind [AppInputCard] and [AppPickerCard].
class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.label,
    required this.value,
    required this.hasError,
    this.padding = defaultPadding,
    this.borderRadius = defaultBorderRadius,
    this.labelStyle,
    this.trailing,
  });

  static const defaultPadding = EdgeInsets.fromLTRB(12, 8, 12, 10);
  static const defaultBorderRadius = 12.0;

  final String label;
  final Widget value;
  final bool hasError;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final TextStyle? labelStyle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: radius,
      ),
      // Painted over the card, so an error doesn't change its size. Always
      // present: adding it later would rebuild the field and close the
      // keyboard.
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: hasError ? AppColors.danger : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            // Read out as one element: the label, then the value.
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style:
                        labelStyle ??
                        Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 9.5,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  value,
                ],
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// [child] with [errorText] underneath while there's an error.
class _FieldWithError extends StatelessWidget {
  const _FieldWithError({required this.child, this.errorText});

  final Widget child;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final errorText = this.errorText;
    // Always a column, so an error appearing doesn't rebuild [child].
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        child,
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Semantics(
              liveRegion: true,
              child: Text(
                errorText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.danger,
                  fontSize: 11.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

TextStyle? _inputValueStyle(BuildContext context) {
  return Theme.of(context).textTheme.titleLarge?.copyWith(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
}

/// A problem with a whole form, such as being offline, shown near its submit
/// button.
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.error_outline_rounded,
                size: 16,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.danger,
                  fontSize: 12.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.borderRadius = 14,
    this.padding = const EdgeInsets.symmetric(vertical: 14),
    this.minHeight = 0,
    this.textStyle,
    this.backgroundColor = AppColors.purple,
    this.foregroundColor = Colors.white,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Shows a spinner instead of the label and ignores taps, while the action
  /// the button started is running.
  final bool loading;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double minHeight;
  final TextStyle? textStyle;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: FilledButton(
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: backgroundColor,
            // A running action keeps the button's colours; only a button that
            // can't be used yet fades.
            disabledBackgroundColor: loading
                ? backgroundColor
                : backgroundColor.withValues(alpha: 0.5),
            foregroundColor: foregroundColor,
            disabledForegroundColor: loading ? foregroundColor : null,
            elevation: 0,
            padding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            textStyle:
                textStyle ??
                Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: foregroundColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Hidden rather than removed, so the button keeps its size and
              // screen readers still hear what it does.
              Opacity(
                opacity: loading ? 0 : 1,
                alwaysIncludeSemantics: true,
                child: Text(label),
              ),
              if (loading)
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foregroundColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class OutlineActionButton extends StatelessWidget {
  const OutlineActionButton({
    required this.label,
    required this.onPressed,
    this.foregroundColor = Colors.white,
    this.backgroundColor,
    this.borderColor,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color foregroundColor;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor,
          backgroundColor: backgroundColor,
          side: BorderSide(
            color: borderColor ?? foregroundColor.withValues(alpha: 0.2),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: foregroundColor,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class OptionChip extends StatelessWidget {
  const OptionChip({
    required this.label,
    required this.selected,
    this.onTap,
    this.selectedColor = AppColors.purple,
    this.selectedBackground = AppColors.purple,
    this.unselectedBackground = AppColors.surfaceSoft,
    this.selectedTextColor = Colors.white,
    this.unselectedTextColor = AppColors.textSecondary,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    this.radius = 999,
    this.textStyle,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color selectedColor;
  final Color selectedBackground;
  final Color unselectedBackground;
  final Color selectedTextColor;
  final Color unselectedTextColor;
  final EdgeInsetsGeometry padding;
  final double radius;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    // Announced as a button that is selected or not, like a toggle.
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: selected ? selectedBackground : unselectedBackground,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Text(
              label,
              style:
                  textStyle ??
                  Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: selected ? selectedTextColor : unselectedTextColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class CircleToggle extends StatelessWidget {
  const CircleToggle({required this.value, required this.onChanged, super.key});

  final bool value;

  /// `null` when something around the toggle, such as its row, handles taps.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: value ? AppColors.purple : Colors.transparent,
          border: Border.all(
            color: value ? AppColors.purple : AppColors.textMuted,
            width: 1.5,
          ),
        ),
        child: value
            ? Center(
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class SectionDivider extends StatelessWidget {
  const SectionDivider({
    required this.label,
    this.textStyle,
    this.horizontalGap = 12,
    super.key,
  });

  final String label;
  final TextStyle? textStyle;
  final double horizontalGap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.divider, height: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalGap),
          child: Text(
            label,
            style:
                textStyle ??
                Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.divider, height: 1)),
      ],
    );
  }
}

class SocialActionCard extends StatelessWidget {
  const SocialActionCard({
    required this.title,
    required this.subtitle,
    this.assetName,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.borderRadius = 14,
    this.borderColor = AppColors.divider,
    this.backgroundColor = Colors.white,
    this.iconSize = 22,
    this.titleStyle,
    this.subtitleStyle,
    super.key,
  });

  final String title;
  final String subtitle;
  final String? assetName;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color borderColor;
  final Color backgroundColor;
  final double iconSize;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        titleStyle ??
                        Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style:
                        subtitleStyle ??
                        Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 11.5,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            if (assetName != null)
              SvgPicture.asset(assetName!, width: iconSize, height: iconSize),
          ],
        ),
      ),
    );
  }
}

class SmallInfoCard extends StatelessWidget {
  const SmallInfoCard({
    required this.title,
    required this.description,
    this.onTap,
    super.key,
  });

  final String title;
  final String description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft.withValues(alpha: .2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 11,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
