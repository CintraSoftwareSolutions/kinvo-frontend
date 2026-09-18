import 'package:flutter/foundation.dart';

import '../../../core/network/api_envelope.dart';

/// One of the photos on the signed-in user's profile.
@immutable
final class ProfilePhoto {
  const ProfilePhoto({
    required this.id,
    required this.url,
    required this.isPrimary,
    this.isRemovedByModerators = false,
  });

  factory ProfilePhoto.fromJson(JsonMap json) {
    if (json case {
      'id': final String id,
      'url': final String? url,
      'is_primary': final bool isPrimary,
    } when id.isNotEmpty) {
      return ProfilePhoto(
        id: id,
        url: url == null ? null : Uri.tryParse(url),
        isPrimary: isPrimary,
        isRemovedByModerators: json['moderation_status'] == 'rejected',
      );
    }
    throw const FormatException(
      'Expected a photo with id, url and is_primary.',
    );
  }

  final String id;

  /// A link to the image that expires. Every read of the photos gives new ones.
  final Uri? url;

  /// The photo shown first, on cards in other people's decks. It's always
  /// the first photo.
  final bool isPrimary;

  /// Moderators took it down, so only its owner still sees it.
  final bool isRemovedByModerators;

  ProfilePhoto withPrimary({required bool isPrimary}) {
    return ProfilePhoto(
      id: id,
      url: url,
      isPrimary: isPrimary,
      isRemovedByModerators: isRemovedByModerators,
    );
  }
}

/// The photos on a profile, in order.
@immutable
final class PhotoAlbum {
  const PhotoAlbum({required this.photos, required this.maxPhotos});

  /// Reads the `data` of `GET /media/photos`.
  factory PhotoAlbum.fromJson(JsonMap json) {
    if (json case {
      'photos': final List<Object?> photos,
      'max_photos': final int maxPhotos,
    } when maxPhotos > 0) {
      return PhotoAlbum(photos: readPhotos(photos), maxPhotos: maxPhotos);
    }
    throw const FormatException('Expected photos and a positive max_photos.');
  }

  /// Reads a list of photos, as the reorder and main photo endpoints return.
  static List<ProfilePhoto> readPhotos(List<Object?> photos) {
    return [
      for (final photo in photos)
        if (photo is JsonMap)
          ProfilePhoto.fromJson(photo)
        else
          throw const FormatException('Expected every photo to be an object.'),
    ];
  }

  final List<ProfilePhoto> photos;
  final int maxPhotos;

  bool get isFull => photos.length >= maxPhotos;

  PhotoAlbum withPhotos(List<ProfilePhoto> photos) {
    return PhotoAlbum(photos: photos, maxPhotos: maxPhotos);
  }

  PhotoAlbum withPhoto(ProfilePhoto photo) => withPhotos([...photos, photo]);

  /// The album without the photo [photoId]. If that was the main photo, the
  /// next one takes its place, as it does on the server.
  PhotoAlbum withoutPhoto(String photoId) {
    final removed = photos.where((photo) => photo.id == photoId).firstOrNull;
    final remaining = [
      for (final photo in photos)
        if (photo.id != photoId) photo,
    ];
    if (removed != null && removed.isPrimary && remaining.isNotEmpty) {
      remaining[0] = remaining[0].withPrimary(isPrimary: true);
    }
    return withPhotos(remaining);
  }

  /// The photos in the order of [photoIds], which must name each photo once.
  /// The first becomes the main photo, as on the server.
  PhotoAlbum reordered(List<String> photoIds) {
    final byId = {for (final photo in photos) photo.id: photo};
    if (photoIds.length != photos.length ||
        !photoIds.every(byId.containsKey) ||
        photoIds.toSet().length != photoIds.length) {
      throw ArgumentError.value(photoIds, 'photoIds', 'Name every photo once.');
    }
    return withPhotos([
      for (final (index, id) in photoIds.indexed)
        byId[id]!.withPrimary(isPrimary: index == 0),
    ]);
  }

  /// The album with [photoId] moved to the front as the main photo, the rest
  /// keeping their order.
  PhotoAlbum withMainPhoto(String photoId) {
    return reordered([
      photoId,
      for (final photo in photos)
        if (photo.id != photoId) photo.id,
    ]);
  }

  /// The ids with the photo at [from] moved to [to], for dragging.
  List<String> idsWithMove(int from, int to) {
    final ids = [for (final photo in photos) photo.id];
    final moved = ids.removeAt(from);
    ids.insert(to.clamp(0, ids.length), moved);
    return ids;
  }
}
