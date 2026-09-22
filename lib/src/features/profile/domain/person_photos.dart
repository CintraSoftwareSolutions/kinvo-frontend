import 'package:flutter/foundation.dart';

/// One of someone else's photos, as the API hands it over.
///
/// Smaller than your own photos: no moderation state, because you are only
/// ever shown photos that have been approved, and no "is this the main one",
/// because the list is in the order they arranged it and the first one is.
@immutable
final class PersonPhotoRef {
  const PersonPhotoRef({
    required this.id,
    required this.url,
    this.width,
    this.height,
  });

  static PersonPhotoRef? tryFromJson(Object? json) {
    if (json case {
      'id': final String id,
      'url': final String url,
    } when id.isNotEmpty && url.isNotEmpty) {
      if (Uri.tryParse(url) case final parsed? when parsed.host.isNotEmpty) {
        return PersonPhotoRef(
          id: id,
          url: parsed,
          width: switch (json) {
            {'width': final int width} when width > 0 => width,
            _ => null,
          },
          height: switch (json) {
            {'height': final int height} when height > 0 => height,
            _ => null,
          },
        );
      }
    }
    return null;
  }

  /// Every approved photo in a `photos` list, in the order it was given.
  static List<PersonPhotoRef> listFromJson(Object? json) {
    return switch (json) {
      final List<Object?> photos => [
        for (final photo in photos) ?PersonPhotoRef.tryFromJson(photo),
      ],
      _ => const [],
    };
  }

  final String id;

  /// A link that expires, so a screen left open long enough shows the person's
  /// initial instead.
  final Uri url;

  /// The picture's size, when the server knows it, so space of the right shape
  /// can be held while it loads.
  final int? width;
  final int? height;
}
