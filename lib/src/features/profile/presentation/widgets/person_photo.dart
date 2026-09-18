import 'dart:io';

import 'package:flutter/material.dart';

/// Someone's photo, or their initial on [color] while it loads, when they
/// have none, or when it can't be shown.
///
/// Photo links from the API expire, so a card left open long enough can hold
/// one that no longer works; the initial covers that too. Links with the
/// `asset:` scheme are bundled images and `file:` links are photos on the
/// device, both of which the demo uses.
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

  @override
  Widget build(BuildContext context) {
    final fallback = _Initial(name: name, color: color, size: initialSize);
    final url = this.url;

    if (url == null) return fallback;
    if (url.scheme == 'asset') {
      return Image.asset(
        url.path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    if (url.scheme == 'file') {
      return Image.file(
        File(url.toFilePath()),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return Image.network(
      url.toString(),
      fit: BoxFit.cover,
      // No photo is shown half-loaded or as a broken image.
      frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return fallback;
      },
      errorBuilder: (_, _, _) => fallback,
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
          colors: [color, Color.lerp(color, Colors.black, 0.4)!],
        ),
      ),
      child: Center(
        child: ExcludeSemantics(
          child: Text(
            trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase(),
            style: TextStyle(
              color: Colors.white,
              fontSize: size,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
