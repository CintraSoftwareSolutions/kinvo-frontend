import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/media/photo_picker.dart';
import 'package:kinvo/src/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:kinvo/src/features/onboarding/presentation/controllers/photos_step_controller.dart';

import '../../../helpers/device_fakes.dart';
import '../../../helpers/fake_kinvo_server.dart';
import '../onboarding_test_setup.dart';

void main() {
  late FakeKinvoServer server;
  late OnboardingTest onboarding;

  PhotosStepController photos() {
    return onboarding.container.read(photosStepControllerProvider.notifier);
  }

  PhotosStepState progress() {
    return onboarding.container.read(photosStepControllerProvider);
  }

  setUp(() async {
    server = FakeKinvoServer();
    onboarding = await OnboardingTest.start(server);
    onboarding
      ..keepAlive(photosStepControllerProvider)
      ..flow.next();
  });

  test('adds a picked photo as the main photo', () async {
    await photos().addPhoto(PhotoSource.library);

    expect(onboarding.backend.photoPicker.requests, [PhotoSource.library]);
    expect(server.photos, hasLength(1));
    expect(onboarding.state.album.photos.single.isPrimary, isTrue);
    expect(onboarding.requests('POST', '/media/photos').single.data, {
      'upload_id': 'upload-1',
      'width': testPhoto.width,
      'height': testPhoto.height,
    });
    expect(progress().isAdding, isFalse);
  });

  test('does nothing when the user cancels', () async {
    onboarding.backend.photoPicker.nextPhoto = null;

    await photos().addPhoto(PhotoSource.camera);

    expect(onboarding.requests('POST', '/media/uploads'), isEmpty);
    expect(progress().isAdding, isFalse);
    expect(progress().error, isNull);
  });

  test('explains a photo that could not be picked', () async {
    onboarding.backend.photoPicker.nextError = const PhotoPickException(
      PhotoPickFailure.accessDenied,
    );

    await photos().addPhoto(PhotoSource.camera);

    expect(progress().error, PhotoPickFailure.accessDenied.message);
    expect(onboarding.state.album.photos, isEmpty);
  });

  test('explains an upload that failed, and allows another try', () async {
    var offline = true;
    server.intercept = (options) async {
      if (offline && options.uri.host == FakeKinvoServer.storageHost) {
        throw const SocketException('Network is unreachable');
      }
      return null;
    };

    await photos().addPhoto(PhotoSource.library);
    expect(progress().error, contains('Check your internet'));
    expect(onboarding.state.album.photos, isEmpty);

    offline = false;
    await photos().addPhoto(PhotoSource.library);
    expect(progress().error, isNull);
    expect(onboarding.state.album.photos, hasLength(1));
  });

  test('adds no more photos than the profile can hold', () async {
    for (var i = 0; i < FakeKinvoServer.maxPhotos + 1; i++) {
      await photos().addPhoto(PhotoSource.library);
    }

    expect(onboarding.state.album.photos, hasLength(FakeKinvoServer.maxPhotos));
    expect(
      onboarding.backend.photoPicker.requests,
      hasLength(FakeKinvoServer.maxPhotos),
    );
  });

  test('removing the main photo makes the next one main', () async {
    await photos().addPhoto(PhotoSource.library);
    await photos().addPhoto(PhotoSource.library);
    final first = onboarding.state.album.photos.first;

    await photos().removePhoto(first.id);

    final remaining = onboarding.state.album.photos;
    expect(remaining.single.isPrimary, isTrue);
    expect(server.photos.single.isPrimary, isTrue);
    expect(progress().removing, isEmpty);
  });

  test('moves on only once there is a photo', () async {
    expect(photos().continueToNext(), isFalse);
    expect(progress().error, PhotosStepController.noPhotosMessage);
    expect(onboarding.state.step, OnboardingStep.photos);

    await photos().addPhoto(PhotoSource.library);

    expect(photos().continueToNext(), isTrue);
    expect(onboarding.state.step, OnboardingStep.interests);
  });

  test('a photo that finishes after leaving the step still counts', () async {
    final picked = photos().addPhoto(PhotoSource.library);
    onboarding.flow.back();
    onboarding.container.invalidate(photosStepControllerProvider);

    await picked;

    expect(onboarding.state.album.photos, hasLength(1));
  });
}
