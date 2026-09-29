import 'package:flutter/material.dart';

import '../../../../core/theme/kinvo_colors.dart';

/// Someone's photo, or their initial on [color] while it loads, when they
/// have none, or when it can't be shown.
///
/// Photo links from the API expire, so a card left open long enough can hold
/// one that no longer works; the initial covers that too.
class PersonPhoto extends StatelessWidget {
  const PersonPhoto({
    required this.url,
    required this.name,
    required this.color,
    this.initialSize = 96,
    super.key,
  });

  final Uri? url;
  final String name;
  final Color color;

  /// The size of the initial shown in place of a photo.
  final double initialSize;

  /// How much wider than it's drawn a photo is decoded, so one that's
  /// landscape still covers a square without being stretched.
  static const _decodeMargin = 1.5;

  @override
  Widget build(BuildContext context) {
    final fallback = _Initial(name: name, color: color, size: initialSize);
    final url = this.url;

    if (url == null) return fallback;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Decoded at the size it's drawn, not the size it was uploaded: a
        // photo is up to 1600 pixels a side, and a list of avatars decoded
        // at that size fills the image cache.
        final side = constraints.biggest.longestSide;
        final decodeWidth = side.isFinite
            ? (side * MediaQuery.devicePixelRatioOf(context) * _decodeMargin)
                  .round()
            : null;
        return Image.network(
          url.toString(),
          fit: BoxFit.cover,
          cacheWidth: decodeWidth,
          // No photo is shown half-loaded or as a broken image.
          frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return fallback;
          },
          errorBuilder: (_, _, _) => fallback,
        );
      },
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.name, required this.color, required this.size});

  final String name;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, Color.lerp(color, OverlayColors.shade, 0.4)!],
        ),
      ),
      child: Center(
        child: ExcludeSemantics(
          child: Text(
            trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase(),
            style: TextStyle(
              color: context.colors.onAccent,
              fontSize: size,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
