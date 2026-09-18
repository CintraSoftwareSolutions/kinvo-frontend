import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/forms/form_errors.dart';
import '../../../../core/media/photo_picker.dart';
import '../../../../core/network/api_exception.dart';
import '../../../profile/data/profile_repository.dart';
import 'onboarding_controller.dart';

/// What's under way on the photos step. The photos themselves are in
/// [OnboardingState.album].
@immutable
final class PhotosStepState {
  const PhotosStepState({
    this.isAdding = false,
    this.removing = const {},
    this.error,
  });

  /// Whether a photo is being picked or uploaded. One is added at a time.
  final bool isAdding;

  /// Photos being deleted.
  final Set<String> removing;

  /// Why the last action failed.
  final String? error;

  PhotosStepState copyWith({
    bool? isAdding,
    Set<String>? removing,
    ValueGetter<String?>? error,
  }) {
    return PhotosStepState(
      isAdding: isAdding ?? this.isAdding,
      removing: removing ?? this.removing,
      error: error == null ? this.error : error(),
    );
  }
}

final photosStepControllerProvider =
    NotifierProvider.autoDispose<PhotosStepController, PhotosStepState>(
      PhotosStepController.new,
    );

class PhotosStepController extends Notifier<PhotosStepState> {
  static const noPhotosMessage = 'Add at least one photo of yourself.';

  @override
  PhotosStepState build() => const PhotosStepState();

  /// Lets the user choose a photo from [source], then uploads it.
  Future<void> addPhoto(PhotoSource source) async {
    final album = ref.read(onboardingControllerProvider).requireValue.album;
    if (state.isAdding || album.isFull) return;
    state = state.copyWith(isAdding: true, error: () => null);

    // Read up front: the step can close while the photo uploads, and the
    // photo still has to be recorded when it does.
    final flow = ref.read(onboardingControllerProvider.notifier);
    final photos = ref.read(photosRepositoryProvider);

    try {
      final picked = await ref.read(photoPickerProvider).pick(source);
      if (picked != null) {
        flow.photoAdded(await photos.addPhoto(picked));
      }
      _finishAdding();
    } on PhotoPickException catch (error) {
      _finishAdding(error: error.failure.message);
    } on ApiException catch (error) {
      _finishAdding(error: error.message);
    } on Object {
      _finishAdding(error: unexpectedFailureMessage);
      rethrow;
    }
  }

  Future<void> removePhoto(String photoId) async {
    if (state.removing.contains(photoId)) return;
    state = state.copyWith(
      removing: {...state.removing, photoId},
      error: () => null,
    );
    final flow = ref.read(onboardingControllerProvider.notifier);

    try {
      await ref.read(photosRepositoryProvider).deletePhoto(photoId);
      flow.photoRemoved(photoId);
      _finishRemoving(photoId);
    } on ApiException catch (error) {
      _finishRemoving(photoId, error: error.message);
    } on Object {
      _finishRemoving(photoId, error: unexpectedFailureMessage);
      rethrow;
    }
  }

  /// Moves on once the profile has a photo. Returns whether it did.
  bool continueToNext() {
    final album = ref.read(onboardingControllerProvider).requireValue.album;
    if (album.photos.isEmpty) {
      state = state.copyWith(error: () => noPhotosMessage);
      return false;
    }
    ref.read(onboardingControllerProvider.notifier).next();
    return true;
  }

  void _finishAdding({String? error}) {
    if (!ref.mounted) return;
    state = state.copyWith(isAdding: false, error: () => error);
  }

  void _finishRemoving(String photoId, {String? error}) {
    if (!ref.mounted) return;
    state = state.copyWith(
      removing: {...state.removing}..remove(photoId),
      error: () => error,
    );
  }
}
