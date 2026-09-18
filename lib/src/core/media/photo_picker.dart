import 'dart:developer' as developer;
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'photo_processing.dart';

/// Where a photo comes from.
enum PhotoSource { camera, library }

/// Why a photo couldn't be picked.
enum PhotoPickFailure {
  /// The user hasn't let the app use the camera or photo library.
  accessDenied(
    'Kinvo needs access to your camera or photos. You can allow it in '
    'Settings.',
  ),

  /// The file isn't an image this app can read, such as a video.
  unreadable("That photo couldn't be opened. Try a different one."),

  /// Anything else went wrong on the device.
  failed("That photo couldn't be added. Please try again.");

  const PhotoPickFailure(this.message);

  /// Text that can be shown to the user as-is.
  final String message;
}

final class PhotoPickException implements Exception {
  const PhotoPickException(this.failure);

  final PhotoPickFailure failure;

  @override
  String toString() => 'PhotoPickException(${failure.name})';
}

/// Lets the user choose a photo and prepares it for upload.
abstract interface class PhotoPicker {
  /// Returns the chosen photo, prepared with [preparePhoto], or `null` when
  /// the user cancelled.
  ///
  /// Throws [PhotoPickException] when a photo couldn't be picked.
  Future<PreparedPhoto?> pick(PhotoSource source);
}

final class DevicePhotoPicker implements PhotoPicker {
  DevicePhotoPicker({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  @override
  Future<PreparedPhoto?> pick(PhotoSource source) async {
    final XFile? file;
    try {
      file = await _imagePicker.pickImage(
        source: switch (source) {
          PhotoSource.camera => ImageSource.camera,
          PhotoSource.library => ImageSource.gallery,
        },
        // Scaled on the device first, which is much faster than in Dart. The
        // quality is left alone because the photo is re-encoded anyway.
        maxWidth: maxPhotoDimension.toDouble(),
        maxHeight: maxPhotoDimension.toDouble(),
        // Picking from the library then needs no photo library permission.
        requestFullMetadata: false,
      );
    } on PlatformException catch (error, stackTrace) {
      _log('Could not pick a photo.', error, stackTrace);
      throw PhotoPickException(
        error.code.contains('access_denied')
            ? PhotoPickFailure.accessDenied
            : PhotoPickFailure.failed,
      );
    }
    if (file == null) return null;

    try {
      final bytes = await file.readAsBytes();
      final prepared = await Isolate.run(() => preparePhoto(bytes));
      if (prepared != null) return prepared;
    } on Object catch (error, stackTrace) {
      // Corrupt or unusual files can make the decoder throw rather than give
      // up quietly.
      _log('Could not read the picked photo.', error, stackTrace);
    }
    throw const PhotoPickException(PhotoPickFailure.unreadable);
  }

  static void _log(String message, Object error, StackTrace stackTrace) {
    developer.log(
      message,
      name: 'kinvo.media',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

final photoPickerProvider = Provider<PhotoPicker>((ref) => DevicePhotoPicker());
