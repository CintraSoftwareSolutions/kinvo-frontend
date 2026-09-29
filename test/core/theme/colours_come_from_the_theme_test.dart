import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Screens take every colour from the theme, as `context.colors`, or from
/// `OverlayColors` for what's drawn over a photo. A colour written into a
/// screen looks right in one of the four palettes and wrong in the other
/// three, which is how the app came to be painted light only.
void main() {
  test('no screen writes a colour of its own', () {
    final colourValue = RegExp(
      r'\bColor\(0x|\bColor\.from(ARGB|RGBO)\(|\bColors\.(?!transparent\b)\w|'
      r'\bAppColors\b',
    );
    final offenders = <String>[];

    for (final file in Directory('lib').listSync(recursive: true)) {
      final path = file.path.replaceAll(r'\', '/');
      if (file is! File || !path.endsWith('.dart')) continue;
      // The palettes themselves, and what reads them into Flutter.
      if (path.startsWith('lib/src/core/theme/')) continue;

      for (final (index, line) in file.readAsLinesSync().indexed) {
        final code = line.split('//').first;
        if (colourValue.hasMatch(code)) {
          offenders.add('$path:${index + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Take the colour from context.colors, or from OverlayColors over a '
          'photo.',
    );
  });
}
