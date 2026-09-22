import 'package:flutter/material.dart';

import '../../domain/person_photos.dart';
import 'person_photo.dart';

/// Someone's photos, one at a time, moved through by tapping either side.
///
/// Tapping rather than swiping, on purpose: this sits inside things that
/// already own horizontal drags — a deck card is swiped left and right to pass
/// and like — and a gallery that competed for that gesture would make both
/// unreliable. Tapping the left or right of a picture is also what every app
/// that shows photos this way does, so it needs no teaching.
///
/// With one photo it is simply that photo, with no marks on it.
class PhotoGallery extends StatefulWidget {
  const PhotoGallery({
    required this.photos,
    required this.name,
    required this.color,
    this.fallbackUrl,
    this.onTapCentre,
    this.initialSize = 96,
    super.key,
  });

  final List<PersonPhotoRef> photos;

  /// Shown as an initial while a photo loads, when there are none, or when a
  /// link has expired.
  final String name;
  final Color color;

  /// Used when [photos] is empty, so a person from a list that carries only
  /// one photo still shows it.
  final Uri? fallbackUrl;

  /// What tapping the middle does, such as opening the full profile. The left
  /// and right thirds always move between photos.
  final VoidCallback? onTapCentre;

  final double initialSize;

  @override
  State<PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery> {
  int _shown = 0;

  @override
  void didUpdateWidget(PhotoGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different person, or a photo removed while this was open.
    if (_shown >= widget.photos.length) _shown = 0;
  }

  void _move(int by) {
    final count = widget.photos.length;
    if (count < 2) return;

    final next = _shown + by;
    if (next < 0 || next >= count) return;
    setState(() => _shown = next);
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    final url = photos.isEmpty
        ? widget.fallbackUrl
        : photos[_shown.clamp(0, photos.length - 1)].url;

    return Stack(
      fit: StackFit.expand,
      children: [
        PersonPhoto(
          url: url,
          name: widget.name,
          color: widget.color,
          initialSize: widget.initialSize,
        ),
        if (photos.length > 1) ...[
          Row(
            children: [
              _TapZone(
                label: 'Previous photo',
                enabled: _shown > 0,
                onTap: () => _move(-1),
              ),
              if (widget.onTapCentre case final openProfile?)
                _TapZone(label: 'Open full profile', onTap: openProfile)
              else
                const Spacer(),
              _TapZone(
                label: 'Next photo',
                enabled: _shown < photos.length - 1,
                onTap: () => _move(1),
              ),
            ],
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: _Progress(count: photos.length, shown: _shown),
          ),
        ] else if (widget.onTapCentre case final openProfile?)
          _TapZone(label: 'Open full profile', onTap: openProfile, wide: true),
      ],
    );
  }
}

/// One third of the picture, listening for a tap.
class _TapZone extends StatelessWidget {
  const _TapZone({
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.wide = false,
  });

  final String label;
  final VoidCallback onTap;

  /// A zone that would do nothing still swallows the tap, so tapping past the
  /// last photo never falls through to what is behind it.
  final bool enabled;

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final zone = Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: const SizedBox.expand(),
      ),
    );

    return wide ? zone : Expanded(child: zone);
  }
}

/// The row of bars along the top saying how many photos there are and which
/// one is showing.
class _Progress extends StatelessWidget {
  const _Progress({required this.count, required this.shown});

  final int count;
  final int shown;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var index = 0; index < count; index++) ...[
              Expanded(
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: index == shown
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(color: Color(0x33000000), blurRadius: 2),
                    ],
                  ),
                ),
              ),
              if (index < count - 1) const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }
}
