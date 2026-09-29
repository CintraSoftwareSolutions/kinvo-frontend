import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'kinvo_colors.dart';

/// The phone's status bar and navigation bar, drawn to suit what's behind
/// them: dark icons over the light theme, light icons over the dark one.
///
/// The app puts one of these around every screen. A screen that's dark at
/// the top in either theme — a call, the welcome screen, a photo opened full
/// size — puts [SystemBars.overDark] around itself, which wins for as long
/// as it's showing.
///
/// Unsized, so it holds wherever what it wraps is drawn: a dialog's content
/// starts below the very status bar it's changing.
class SystemBars extends StatelessWidget {
  const SystemBars({required this.child, super.key}) : _overDark = false;

  /// For a screen that's dark whatever the theme.
  const SystemBars.overDark({required this.child, super.key})
    : _overDark = true;

  final Widget child;
  final bool _overDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final darkBehind = _overDark || colors.isDark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      sized: false,
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        // Android is told the icons' brightness; iOS, the background's.
        statusBarIconBrightness: darkBehind
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: darkBehind ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: _overDark
            ? OverlayColors.shade
            : colors.surface,
        systemNavigationBarIconBrightness: darkBehind
            ? Brightness.light
            : Brightness.dark,
      ),
      child: child,
    );
  }
}
