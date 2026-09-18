import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// A photo ready to upload: a JPEG with nothing in it but the picture.
@immutable
final class PreparedPhoto {
  const PreparedPhoto({
    required this.bytes,
    required this.width,
    required this.height,
  });

  static const mimeType = 'image/jpeg';

  final Uint8List bytes;
  final int width;
  final int height;
}

/// Longest side of an uploaded photo. More detail than a phone screen shows
/// only slows uploads on mobile data.
const maxPhotoDimension = 1600;

const _jpegQuality = 85;

/// Turns [bytes] of a picked photo into what gets uploaded, or returns `null`
/// when they aren't an image this app can read.
///
/// The photo is decoded and re-encoded, so only its pixels leave the device.
/// Camera photos carry metadata such as where they were taken, and a profile
/// photo is visible to strangers. The rotation that metadata describes is
/// applied to the pixels first, so the photo still appears the right way up.
///
/// Decoding is slow for large photos; run this away from the UI isolate.
PreparedPhoto? preparePhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  var photo = img.bakeOrientation(decoded);
  if (photo.width > maxPhotoDimension || photo.height > maxPhotoDimension) {
    photo = img.copyResize(
      photo,
      width: photo.width >= photo.height ? maxPhotoDimension : null,
      height: photo.height > photo.width ? maxPhotoDimension : null,
      interpolation: img.Interpolation.average,
    );
  }
  if (photo.hasAlpha) {
    // JPEG has no transparency; show it against white rather than black.
    photo = img.compositeImage(
      img.Image(width: photo.width, height: photo.height)
        ..clear(img.ColorRgb8(255, 255, 255)),
      photo,
    );
  }
  photo
    ..exif = img.ExifData()
    ..iccProfile = null
    ..textData = null;

  return PreparedPhoto(
    bytes: img.encodeJpg(photo, quality: _jpegQuality),
    width: photo.width,
    height: photo.height,
  );
}
