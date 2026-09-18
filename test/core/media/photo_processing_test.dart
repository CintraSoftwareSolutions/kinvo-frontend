import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kinvo/src/core/media/photo_processing.dart';

/// A camera-style JPEG: taken sideways, with its location in the metadata.
Uint8List _cameraPhoto({required int width, required int height}) {
  final photo = img.Image(width: width, height: height)
    ..clear(img.ColorRgb8(200, 80, 40));
  photo.exif.imageIfd.orientation = 6;
  photo.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(53, 1);
  photo.exif.imageIfd['Make'] = img.IfdValueAscii('PhoneCo');
  return img.encodeJpg(photo);
}

void main() {
  test('strips the metadata but keeps the photo the right way up', () {
    final prepared = preparePhoto(_cameraPhoto(width: 400, height: 300))!;

    final decoded = img.decodeJpg(prepared.bytes)!;
    expect(decoded.exif.isEmpty, isTrue);
    // Orientation 6 means a quarter turn, which is now in the pixels.
    expect((prepared.width, prepared.height), (300, 400));
    expect((decoded.width, decoded.height), (300, 400));
  });

  test('scales large photos down to the longest side allowed', () {
    final prepared = preparePhoto(
      img.encodeJpg(img.Image(width: 3200, height: 2400)),
    )!;

    expect((prepared.width, prepared.height), (maxPhotoDimension, 1200));
  });

  test('leaves small photos their size', () {
    final prepared = preparePhoto(
      img.encodeJpg(img.Image(width: 640, height: 480)),
    )!;

    expect((prepared.width, prepared.height), (640, 480));
  });

  test('turns transparent images into white-backed JPEGs', () {
    final transparent = img.Image(width: 10, height: 10, numChannels: 4)
      ..clear(img.ColorRgba8(0, 0, 0, 0));

    final prepared = preparePhoto(img.encodePng(transparent))!;

    final pixel = img.decodeJpg(prepared.bytes)!.getPixel(5, 5);
    expect(pixel.r, greaterThan(240));
    expect(pixel.g, greaterThan(240));
    expect(pixel.b, greaterThan(240));
  });

  test('gives up on files that are not images', () {
    expect(preparePhoto(Uint8List.fromList('not a photo'.codeUnits)), isNull);
  });
}
