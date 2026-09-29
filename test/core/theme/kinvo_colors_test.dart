import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/theme/kinvo_colors.dart';

/// Each palette is held to the contrast its text and controls need, after
/// WCAG 2.2: 4.5:1 for text, 3:1 for icons, outlines and bold labels, and
/// more from the higher-contrast palettes, which are for people who find the
/// standard ones hard to read.
void main() {
  const palettes = {
    'light': KinvoColors.light,
    'light, higher contrast': KinvoColors.lightHighContrast,
    'dark': KinvoColors.dark,
    'dark, higher contrast': KinvoColors.darkHighContrast,
  };

  double contrast(Color a, Color b) {
    final (x, y) = (a.computeLuminance(), b.computeLuminance());
    return (max(x, y) + 0.05) / (min(x, y) + 0.05);
  }

  /// Every pair in [pairs] that falls short, so one run names them all.
  void expectContrast(List<(String, Color, Color, double)> pairs) {
    final shortfalls = [
      for (final (label, foreground, background, needed) in pairs)
        if (contrast(foreground, background) < needed)
          '$label: ${contrast(foreground, background).toStringAsFixed(2)}:1, '
              'needs $needed:1',
    ];
    expect(shortfalls, isEmpty);
  }

  for (final MapEntry(key: name, value: colors) in palettes.entries) {
    final higher = colors.highContrast;

    group('the $name palette', () {
      test('has text that reads on every background', () {
        expectContrast([
          for (final (backgroundName, background) in [
            ('background', colors.background),
            ('surface', colors.surface),
            ('soft surface', colors.surfaceSoft),
          ]) ...[
            ('text on $backgroundName', colors.textPrimary, background, 7),
            (
              'secondary text on $backgroundName',
              colors.textSecondary,
              background,
              higher ? 7 : 4.5,
            ),
            // Hints and times, which the standard palettes keep quiet on
            // purpose. Higher contrast brings them up to full text.
            (
              'muted text on $backgroundName',
              colors.textMuted,
              background,
              higher ? 4.5 : 2.3,
            ),
          ],
        ]);
      });

      test('has an accent that reads, with white that reads on it', () {
        expectContrast([
          ('white on the accent', colors.onAccent, colors.purple, 4.5),
          // The accent also carries white text, which caps how light it can
          // go on a dark card: 4:1 is the most both allow.
          (
            'the accent on a card',
            colors.purple,
            colors.surface,
            higher ? 4 : 3,
          ),
          (
            'the accent on the background',
            colors.purple,
            colors.background,
            higher ? 4 : 3,
          ),
          ('the accent on its soft fill', colors.purple, colors.purpleSoft, 3),
        ]);
      });

      test('has warnings and good news that read', () {
        expectContrast([
          ('danger on a card', colors.danger, colors.surface, higher ? 4 : 3),
          ('white on danger', colors.onAccent, colors.danger, higher ? 4.5 : 3),
          (
            'danger text on its soft fill',
            colors.dangerStrong,
            colors.dangerSoft,
            4.5,
          ),
          ('good news on a card', colors.green, colors.surface, 4.5),
          ('blue on a card', colors.blue, colors.surface, 3),
          ('white on blue', colors.onAccent, colors.blue, higher ? 4.5 : 3),
        ]);
      });

      test("has each hue's text reading on its soft fill", () {
        expectContrast([
          for (final hue in Hue.values)
            (
              '${hue.name} on its soft fill',
              colors.tint(hue).onSoft,
              colors.tint(hue).soft,
              4.5,
            ),
        ]);
      });

      if (colors.isDark || higher) {
        test('has each hue showing on a card, as an icon', () {
          expectContrast([
            for (final hue in Hue.values)
              (
                '${hue.name} on a card',
                colors.tint(hue).color,
                colors.surface,
                3,
              ),
          ]);
        });
      }

      if (higher) {
        test('has white reading on every hue', () {
          expectContrast([
            for (final hue in Hue.values)
              (
                'white on ${hue.name}',
                colors.onAccent,
                colors.tint(hue).color,
                4.5,
              ),
          ]);
        });

        test('has outlines and separators that stand out', () {
          expectContrast([
            ('outlines', colors.border, colors.surface, 3),
            ('the grab bar of a sheet', colors.handle, colors.surface, 3),
            ('separators', colors.divider, colors.surface, 2),
          ]);
        });
      }
    });
  }

  test('there is a palette for each brightness, with and without contrast', () {
    expect(KinvoColors.of(Brightness.light), same(KinvoColors.light));
    expect(
      KinvoColors.of(Brightness.light, highContrast: true),
      same(KinvoColors.lightHighContrast),
    );
    expect(KinvoColors.of(Brightness.dark), same(KinvoColors.dark));
    expect(
      KinvoColors.of(Brightness.dark, highContrast: true),
      same(KinvoColors.darkHighContrast),
    );
    for (final MapEntry(key: name, value: colors) in palettes.entries) {
      expect(colors.tints.keys, containsAll(Hue.values), reason: name);
      expect(
        colors.isDark,
        name.startsWith('dark'),
        reason: '$name says what it is',
      );
      expect(colors.highContrast, name.contains('higher'), reason: name);
    }
  });

  test('a blend between two palettes ends on the second', () {
    final blended = KinvoColors.light.lerp(KinvoColors.dark, 1);

    expect(blended.brightness, Brightness.dark);
    expect(blended.background, KinvoColors.dark.background);
    expect(blended.textPrimary, KinvoColors.dark.textPrimary);
    expect(
      blended.tint(Hue.amber).onSoft,
      KinvoColors.dark.tint(Hue.amber).onSoft,
    );
  });
}
