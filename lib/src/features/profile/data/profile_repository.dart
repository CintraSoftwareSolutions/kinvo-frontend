import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/geo_point.dart';
import '../../../core/media/media_uploader.dart';
import '../../../core/media/photo_processing.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';
import '../../../core/network/api_envelope.dart';
import '../domain/own_profile.dart';
import '../domain/profile_fields.dart';
import '../domain/profile_photo.dart';
import '../domain/public_profile.dart';

/// Reads and changes the signed-in user's profile.
///
/// Failures are `ApiException`s.
abstract interface class ProfileRepository {
  Future<OwnProfile> fetchOwnProfile();

  /// Changes the details in [changes] and leaves the rest alone. A `null`
  /// value clears that detail.
  Future<OwnProfile> updateDetails(Map<ProfileField, Object?> changes);

  /// Sets where the profile is. [point] should already be approximate.
  Future<OwnProfile> updateLocation(
    GeoPoint point, {
    String? city,
    String? countryCode,
  });

  /// Replaces the profile's interests with [slugs].
  Future<OwnProfile> setInterests(List<String> slugs);

  /// Replaces the prompt answers with [answers], shown in that order.
  Future<OwnProfile> setPrompts(List<PromptAnswer> answers);

  /// The profile exactly as other people see it.
  Future<PublicProfile> fetchPreview();
}

/// [ProfileRepository] on the Kinvo API.
final class ApiProfileRepository implements ProfileRepository {
  const ApiProfileRepository(this._api);

  final ApiClient _api;

  @override
  Future<OwnProfile> fetchOwnProfile() {
    return _api.get('/users/me', decode: OwnProfile.fromJson);
  }

  @override
  Future<OwnProfile> updateDetails(Map<ProfileField, Object?> changes) {
    if (changes.isEmpty) {
      throw ArgumentError.value(changes, 'changes', 'Change something.');
    }
    return _api.patch(
      '/users/me',
      body: {
        for (final MapEntry(:key, :value) in changes.entries)
          key.apiName: value,
      },
      decode: OwnProfile.fromJson,
    );
  }

  @override
  Future<OwnProfile> updateLocation(
    GeoPoint point, {
    String? city,
    String? countryCode,
  }) {
    return _api.patch(
      '/users/me/location',
      body: {
        'latitude': point.latitude,
        'longitude': point.longitude,
        'city': ?city,
        'country': ?countryCode,
      },
      decode: OwnProfile.fromJson,
    );
  }

  @override
  Future<OwnProfile> setInterests(List<String> slugs) {
    return _api.put(
      '/users/me/interests',
      body: {'interests': slugs},
      decode: OwnProfile.fromJson,
    );
  }

  @override
  Future<OwnProfile> setPrompts(List<PromptAnswer> answers) {
    return _api.put(
      '/users/me/prompts',
      body: {
        'prompts': [
          for (final answer in answers)
            {'slug': answer.slug, 'answer': answer.answer.trim()},
        ],
      },
      decode: OwnProfile.fromJson,
    );
  }

  @override
  Future<PublicProfile> fetchPreview() {
    return _api.get('/users/me/preview', decode: PublicProfile.fromJson);
  }
}

/// The repository the profile uses.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ApiProfileRepository(ref.watch(apiClientProvider));
});

/// Adds, removes and orders the signed-in user's profile photos.
abstract interface class PhotosRepository {
  Future<PhotoAlbum> fetchAlbum();

  /// Uploads [photo] and adds it after the existing ones. The first photo on
  /// a profile becomes its main photo.
  Future<ProfilePhoto> addPhoto(PreparedPhoto photo);

  /// Deletes a photo. Once onboarding is done, the server keeps the last one.
  Future<void> deletePhoto(String photoId);

  /// Puts the photos in the order of [photoIds], which must name each once.
  /// The first becomes the main photo. Returns the photos as saved.
  Future<List<ProfilePhoto>> reorder(List<String> photoIds);

  /// Makes [photoId] the main photo, moving it to the front. Returns the
  /// photos as saved.
  Future<List<ProfilePhoto>> makeMain(String photoId);
}

/// [PhotosRepository] on the Kinvo API.
final class ApiPhotosRepository implements PhotosRepository {
  const ApiPhotosRepository({
    required ApiClient api,
    required MediaUploader uploader,
  }) : _api = api,
       _uploader = uploader;

  final ApiClient _api;
  final MediaUploader _uploader;

  @override
  Future<PhotoAlbum> fetchAlbum() {
    return _api.get('/media/photos', decode: PhotoAlbum.fromJson);
  }

  @override
  Future<ProfilePhoto> addPhoto(PreparedPhoto photo) async {
    final uploadId = await _uploader.upload(
      purpose: UploadPurpose.profilePhoto,
      bytes: photo.bytes,
      mimeType: PreparedPhoto.mimeType,
    );
    return _api.post(
      '/media/photos',
      body: {
        'upload_id': uploadId,
        'width': photo.width,
        'height': photo.height,
      },
      decode: ProfilePhoto.fromJson,
    );
  }

  @override
  Future<void> deletePhoto(String photoId) {
    return _api.delete(
      '/media/photos/${Uri.encodeComponent(photoId)}',
      decode: ApiClient.ignoreData,
    );
  }

  @override
  Future<List<ProfilePhoto>> reorder(List<String> photoIds) {
    return _api.patch(
      '/media/photos/reorder',
      body: {'photo_ids': photoIds},
      decode: _readPhotos,
    );
  }

  @override
  Future<List<ProfilePhoto>> makeMain(String photoId) {
    return _api.patch(
      '/media/photos/${Uri.encodeComponent(photoId)}/primary',
      decode: _readPhotos,
    );
  }

  static List<ProfilePhoto> _readPhotos(JsonMap json) {
    if (json case {'photos': final List<Object?> photos}) {
      return PhotoAlbum.readPhotos(photos);
    }
    throw const FormatException('Expected photos.');
  }
}

/// The repository photos use.
final photosRepositoryProvider = Provider<PhotosRepository>((ref) {
  return ApiPhotosRepository(
    api: ref.watch(apiClientProvider),
    uploader: ref.watch(mediaUploaderProvider),
  );
});
