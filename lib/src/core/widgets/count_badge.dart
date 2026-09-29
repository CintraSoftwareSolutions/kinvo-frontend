import 'package:flutter/material.dart';

import '../theme/kinvo_colors.dart';

/// How big a [CountBadge] is drawn.
enum CountBadgeSize {
  /// On an icon: a tab, the bell.
  small,

  /// On a photo, or beside a row's title.
  large,
}

/// How many of something want attention — unread notifications, unread
/// messages, plans waiting on an answer — in a red pill.
///
/// Draws nothing at zero, and "99+" past ninety-nine, which is all the pill
/// holds. Screen readers hear the count from what the badge is on, so the
/// pill itself says nothing to them.
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {this.size = CountBadgeSize.small, super.key});

  final int count;
  final CountBadgeSize size;

  /// [count] as a badge shows it.
  static String label(int count) => count > 99 ? '99+' : '$count';

  /// Larger text makes the count larger, but only so far: the pill sits on
  /// an icon, and at full scale it would cover it.
  static const _maxTextScale = 1.3;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final colors = context.colors;
    final (side, fontSize, ring) = switch (size) {
      CountBadgeSize.small => (16.0, 9.5, 1.5),
      CountBadgeSize.large => (20.0, 10.5, 2.0),
    };

    return ExcludeSemantics(
      child: Container(
        constraints: BoxConstraints(minWidth: side, minHeight: side),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: colors.danger,
          borderRadius: BorderRadius.circular(999),
          // Keeps the pill apart from what it overlaps.
          border: Border.all(color: colors.surface, width: ring),
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Text(
            label(count),
            maxLines: 1,
            textAlign: TextAlign.center,
            textScaler: MediaQuery.textScalerOf(
              context,
            ).clamp(maxScaleFactor: _maxTextScale),
            style: TextStyle(
              color: colors.onAccent,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
