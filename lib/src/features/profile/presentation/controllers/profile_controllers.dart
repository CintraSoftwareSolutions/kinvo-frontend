import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../../core/config/server_config.dart';
import '../../../../core/config/server_config_providers.dart';
import '../../../../core/demo/demo_mode.dart';
import '../../../../core/forms/form_errors.dart';
import '../../../../core/media/photo_picker.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/demo_profile_repository.dart';
import '../../data/profile_repository.dart';
import '../../domain/own_profile.dart';
import '../../domain/profile_fields.dart';
import '../../domain/profile_photo.dart';
import '../../domain/public_profile.dart';

/// The signed-in user's own profile.
///
/// Kept for the whole session, so the Profile tab opens at once after the
/// first visit. Starts again when the session changes.
final ownProfileProvider =
    AsyncNotifierProvider<OwnProfileController, OwnProfile>(
      OwnProfileController.new,
    );

class OwnProfileController extends AsyncNotifier<OwnProfile> {
  @override
  Future<OwnProfile> build() {
    ref.watch(sessionStatusProvider);
    return ref.watch(profileRepositoryProvider).fetchOwnProfile();
  }

  /// Saves [changes], a `null` value clearing that detail. Throws an
  /// `ApiException` when the server refuses, leaving the profile as it was.
  Future<void> updateDetails(Map<ProfileField, Object?> changes) {
    return _save((profiles) => profiles.updateDetails(changes));
  }

  /// Replaces the interests with [slugs]. Throws as [updateDetails] does.
  Future<void> setInterests(List<String> slugs) {
    return _save((profiles) => profiles.setInterests(slugs));
  }

  /// Replaces the prompt answers with [answers]. Throws as [updateDetails]
  /// does.
  Future<void> setPrompts(List<PromptAnswer> answers) {
    return _save((profiles) => profiles.setPrompts(answers));
  }

  /// Reads the profile again without showing it as loading, for when
  /// something that counts towards it changed elsewhere, such as its photos.
  /// When that fails, what's shown stays.
  Future<void> refreshQuietly() async {
    try {
      final profile = await ref
          .read(profileRepositoryProvider)
          .fetchOwnProfile();
      if (ref.mounted) state = AsyncData(profile);
    } on ApiException catch (error) {
      developer.log(
        'Could not refresh the profile: ${error.message}',
        name: 'kinvo.profile',
      );
    }
  }

  Future<void> _save(
    Future<OwnProfile> Function(ProfileRepository profiles) save,
  ) async {
    final saved = await save(ref.read(profileRepositoryProvider));
    if (ref.mounted) state = AsyncData(saved);
  }
}

/// The profile as other people see it, read afresh each time it's shown.
final ownPreviewProvider = FutureProvider.autoDispose<PublicProfile>(
  (ref) => ref.watch(profileRepositoryProvider).fetchPreview(),
);

/// The interests, prompts, lifestyle answers and limits a profile can use:
/// the server's catalogue, or the demo's, which runs without a connection.
final profileCatalogueProvider = Provider<AsyncValue<ServerConfig>>((ref) {
  if (ref.watch(demoSessionProvider)) {
    return const AsyncData(DemoProfile.catalogue);
  }
  return ref.watch(serverConfigProvider);
});

/// What's happening to the photos right now.
@immutable
final class PhotoEdits {
  const PhotoEdits({
    this.isAdding = false,
    this.removing = const {},
    this.isArranging = false,
    this.error,
  });

  /// A photo is being picked or uploaded. One is added at a time.
  final bool isAdding;

  /// Photos being deleted.
  final Set<String> removing;

  /// The order or the main photo is being saved.
  final bool isArranging;

  /// Why the last change failed, to show once.
  final String? error;

  bool get isBusy => isAdding || isArranging || removing.isNotEmpty;

  PhotoEdits copyWith({
    bool? isAdding,
    Set<String>? removing,
    bool? isArranging,
    ValueGetter<String?>? error,
  }) {
    return PhotoEdits(
      isAdding: isAdding ?? this.isAdding,
      removing: removing ?? this.removing,
      isArranging: isArranging ?? this.isArranging,
      error: error == null ? this.error : error(),
    );
  }
}

/// The signed-in user's photos, and changes to them under way.
///
/// Changes show at once and are undone if the server refuses them. The
/// profile is read again afterwards, since photos count towards completing
/// it.
final profilePhotosProvider =
    AsyncNotifierProvider.autoDispose<ProfilePhotosController, PhotoAlbum>(
      ProfilePhotosController.new,
    );

final photoEditsProvider =
    NotifierProvider.autoDispose<PhotoEditsController, PhotoEdits>(
      PhotoEditsController.new,
    );

class PhotoEditsController extends Notifier<PhotoEdits> {
  @override
  PhotoEdits build() => const PhotoEdits();

  void update(PhotoEdits Function(PhotoEdits edits) change) {
    state = change(state);
  }

  /// Forgets the last error once it's been shown.
  void clearError() => state = state.copyWith(error: () => null);
}

class ProfilePhotosController extends AsyncNotifier<PhotoAlbum> {
  @override
  Future<PhotoAlbum> build() {
    return ref.watch(photosRepositoryProvider).fetchAlbum();
  }

  PhotoEditsController get _edits => ref.read(photoEditsProvider.notifier);

  /// Lets the user choose a photo from [source], then uploads it and adds it
  /// after the others.
  Future<void> addPhoto(PhotoSource source) async {
    final album = state.value;
    final edits = ref.read(photoEditsProvider);
    if (album == null || album.isFull || edits.isBusy) return;
    _edits.update((edits) => edits.copyWith(isAdding: true, error: () => null));

    final photos = ref.read(photosRepositoryProvider);
    String? error;
    try {
      final picked = await ref.read(photoPickerProvider).pick(source);
      if (picked != null) {
        final added = await photos.addPhoto(picked);
        if (ref.mounted) {
          state = AsyncData(state.requireValue.withPhoto(added));
        }
        _profileChanged();
      }
    } on PhotoPickException catch (failure) {
      error = failure.failure.message;
    } on ApiException catch (failure) {
      error = saveFailureMessage(failure);
    } finally {
      if (ref.mounted) {
        _edits.update(
          (edits) => edits.copyWith(isAdding: false, error: () => error),
        );
      }
    }
  }

  /// Deletes [photoId]. It disappears at once and comes back if the server
  /// keeps it, as it does with the last photo once onboarding is done.
  Future<void> removePhoto(String photoId) async {
    final album = state.value;
    if (album == null ||
        ref.read(photoEditsProvider).removing.contains(photoId)) {
      return;
    }
    _edits.update(
      (edits) => edits.copyWith(
        removing: {...edits.removing, photoId},
        error: () => null,
      ),
    );
    state = AsyncData(album.withoutPhoto(photoId));

    String? error;
    try {
      await ref.read(photosRepositoryProvider).deletePhoto(photoId);
      _profileChanged();
    } on ApiException catch (failure) {
      error = saveFailureMessage(failure);
      if (ref.mounted) await _reload(fallback: album);
    } finally {
      if (ref.mounted) {
        _edits.update(
          (edits) => edits.copyWith(
            removing: {...edits.removing}..remove(photoId),
            error: () => error,
          ),
        );
      }
    }
  }

  /// Puts the photos in the order of [photoIds]; the first becomes the main
  /// photo.
  Future<void> reorder(List<String> photoIds) {
    return _arrange(
      (album) => album.reordered(photoIds),
      (photos) => photos.reorder(photoIds),
    );
  }

  /// Makes [photoId] the main photo, moving it to the front.
  Future<void> makeMain(String photoId) {
    return _arrange(
      (album) => album.withMainPhoto(photoId),
      (photos) => photos.makeMain(photoId),
    );
  }

  Future<void> _arrange(
    PhotoAlbum Function(PhotoAlbum album) change,
    Future<List<ProfilePhoto>> Function(PhotosRepository photos) save,
  ) async {
    final album = state.value;
    if (album == null || ref.read(photoEditsProvider).isBusy) return;
    _edits.update(
      (edits) => edits.copyWith(isArranging: true, error: () => null),
    );
    state = AsyncData(change(album));

    String? error;
    try {
      final saved = await save(ref.read(photosRepositoryProvider));
      if (ref.mounted) state = AsyncData(album.withPhotos(saved));
    } on ApiException catch (failure) {
      error = saveFailureMessage(failure);
      if (ref.mounted) state = AsyncData(album);
    } finally {
      if (ref.mounted) {
        _edits.update(
          (edits) => edits.copyWith(isArranging: false, error: () => error),
        );
      }
    }
  }

  /// Reads the photos again after a failed change, since the server may have
  /// done part of it. Shows [fallback] when that fails too.
  Future<void> _reload({required PhotoAlbum fallback}) async {
    try {
      final album = await ref.read(photosRepositoryProvider).fetchAlbum();
      if (ref.mounted) state = AsyncData(album);
    } on ApiException {
      if (ref.mounted) state = AsyncData(fallback);
    }
  }

  void _profileChanged() {
    if (ref.exists(ownProfileProvider)) {
      ref.read(ownProfileProvider.notifier).refreshQuietly().ignore();
    }
  }
}
