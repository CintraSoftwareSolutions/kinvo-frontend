import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/auth/auth_providers.dart';
import 'package:kinvo/src/core/media/photo_picker.dart';
import 'package:kinvo/src/core/network/api_exception.dart';
import 'package:kinvo/src/features/profile/domain/own_profile.dart';
import 'package:kinvo/src/features/profile/domain/profile_fields.dart';
import 'package:kinvo/src/features/profile/domain/profile_photo.dart';
import 'package:kinvo/src/features/profile/presentation/controllers/profile_controllers.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/auth_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_kinvo_server.dart';
import '../../helpers/test_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeKinvoServer server;
  late TestBackend backend;
  late ProviderContainer container;

  setUp(() async {
    server = FakeKinvoServer()
      ..completeProfile()
      ..isOnboarded = true;
    backend = TestBackend(respond: server.respond, realtime: server.realtime);
    await backend.tokenStore.write(liveSession());
    container = backend.createContainer(clock: server.now);
    await container.read(sessionManagerProvider).ready;
  });

  Future<OwnProfile> profile() {
    container.listen(ownProfileProvider, (_, _) {});
    return container.read(ownProfileProvider.future);
  }

  OwnProfileController profiles() {
    return container.read(ownProfileProvider.notifier);
  }

  test('reads the profile and what it is missing', () async {
    final loaded = await profile();

    // A photo and a location, out of the server's whole checklist.
    expect(loaded.displayName, 'Sam Taylor');
    expect(loaded.completionPercentage, 32);
    expect(loaded.completionMissing.map((step) => step.key), [
      'bio',
      'interests',
      'prompts',
      'work',
      'lifestyle',
      'education',
    ]);
  });

  test('saves a detail and shows the profile the server returns', () async {
    await profile();

    await profiles().updateDetails({ProfileField.jobTitle: 'Designer'});

    expect(server.jobTitle, 'Designer');
    expect(container.read(ownProfileProvider).value?.jobTitle, 'Designer');
  });

  test('clears a detail when given nothing for it', () async {
    server.jobTitle = 'Designer';
    await profile();

    await profiles().updateDetails({ProfileField.jobTitle: null});

    final sent = backend.requestsTo('/users/me').last.data;
    expect(sent, {'job_title': null});
    expect(server.jobTitle, isNull);
    expect(container.read(ownProfileProvider).value?.jobTitle, isNull);
  });

  test('keeps the profile as it was when the server refuses', () async {
    await profile();

    await expectLater(
      profiles().updateDetails({ProfileField.heightCm: 300}),
      throwsA(isA<ApiErrorException>()),
    );

    expect(server.heightCm, isNull);
    expect(container.read(ownProfileProvider).value?.heightCm, isNull);
  });

  test('replaces the prompt answers, in order', () async {
    await profile();

    await profiles().setPrompts(const [
      PromptAnswer(
        slug: 'go_to_order',
        question: 'My go-to order is…',
        answer: '  A flat white.  ',
      ),
      PromptAnswer(
        slug: 'talk_for_hours',
        question: 'I could talk for hours about…',
        answer: 'Maps.',
      ),
    ]);

    expect(server.prompts, [
      (slug: 'go_to_order', answer: 'A flat white.'),
      (slug: 'talk_for_hours', answer: 'Maps.'),
    ]);
    final saved = container.read(ownProfileProvider).value!;
    expect(saved.prompts.map((prompt) => prompt.slug), [
      'go_to_order',
      'talk_for_hours',
    ]);
  });

  test('replaces the interests', () async {
    await profile();

    await profiles().setInterests(['music', 'running', 'coffee']);

    expect(server.interests, ['music', 'running', 'coffee']);
    expect(container.read(ownProfileProvider).value?.interestSlugs, [
      'music',
      'running',
      'coffee',
    ]);
  });

  group('photos', () {
    Future<PhotoAlbum> album() {
      container
        ..listen(profilePhotosProvider, (_, _) {})
        ..listen(photoEditsProvider, (_, _) {});
      return container.read(profilePhotosProvider.future);
    }

    ProfilePhotosController photos() {
      return container.read(profilePhotosProvider.notifier);
    }

    List<String> shown() => [
      for (final photo in container.read(profilePhotosProvider).value!.photos)
        photo.id,
    ];

    PhotoEdits edits() => container.read(photoEditsProvider);

    void serverHas(List<String> ids) {
      server.photos
        ..clear()
        ..addAll([
          for (final (index, id) in ids.indexed)
            (id: id, isPrimary: index == 0),
        ]);
    }

    test('adds a picked photo after the others', () async {
      await profile();
      await album();

      await photos().addPhoto(PhotoSource.library);

      expect(server.photos, hasLength(2));
      expect(shown(), ['photo-0', server.photos.last.id]);
      expect(edits().isAdding, isFalse);
      expect(edits().error, isNull);
      expect(backend.photoPicker.requests, [PhotoSource.library]);
    });

    test('says why a photo could not be picked', () async {
      await album();
      backend.photoPicker.nextError = const PhotoPickException(
        PhotoPickFailure.accessDenied,
      );

      await photos().addPhoto(PhotoSource.camera);

      expect(edits().error, PhotoPickFailure.accessDenied.message);
      expect(server.photos, hasLength(1));
    });

    test('deletes a photo', () async {
      serverHas(['a', 'b']);
      await album();

      await photos().removePhoto('a');

      expect(shown(), ['b']);
      expect(server.photos.single.id, 'b');
      expect(edits().removing, isEmpty);
    });

    test('puts the last photo back when the server keeps it', () async {
      await album();

      await photos().removePhoto('photo-0');

      expect(shown(), ['photo-0']);
      expect(edits().error, contains('at least one photo'));
    });

    test('makes a photo the main one by moving it to the front', () async {
      serverHas(['a', 'b', 'c']);
      await album();

      await photos().makeMain('c');

      expect(shown(), ['c', 'a', 'b']);
      expect(server.photos.map((photo) => photo.id), ['c', 'a', 'b']);
      expect(server.photos.first.isPrimary, isTrue);
    });

    test('reorders, and puts them back when the server refuses', () async {
      serverHas(['a', 'b', 'c']);
      await album();

      await photos().reorder(['b', 'c', 'a']);
      expect(shown(), ['b', 'c', 'a']);
      expect(server.photos.map((photo) => photo.id), ['b', 'c', 'a']);

      server.intercept = (options) async {
        if (options.path.endsWith('/reorder')) {
          return jsonResponse(
            409,
            errorEnvelope('CONFLICT', 'Your photos changed on another device.'),
          );
        }
        return null;
      };
      await photos().reorder(['a', 'b', 'c']);

      expect(shown(), ['b', 'c', 'a']);
      expect(edits().error, 'Your photos changed on another device.');
    });

    test('updates how complete the profile is after a change', () async {
      server.photos.clear();
      await profile();
      await album();
      expect(
        container.read(ownProfileProvider).value!.completionMissing.first.key,
        'photos',
      );

      await photos().addPhoto(PhotoSource.library);
      await settle();

      final keys = container
          .read(ownProfileProvider)
          .value!
          .completionMissing
          .map((step) => step.key);
      expect(keys, isNot(contains('photos')));
    });
  });
}
