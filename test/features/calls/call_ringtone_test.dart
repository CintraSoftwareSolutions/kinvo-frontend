import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/ringtone/ringtone.dart';
import 'package:kinvo/src/core/storage/key_value_store.dart';
import 'package:kinvo/src/core/storage/storage_providers.dart';
import 'package:kinvo/src/features/calls/presentation/controllers/call_ringtone_controller.dart';

import '../../helpers/fake_ringtones.dart';
import '../../helpers/in_memory_key_value_store.dart';

ProviderContainer _container(Ringtones ringtones, KeyValueStore store) {
  final container = ProviderContainer(
    overrides: [
      ringtonesProvider.overrideWithValue(ringtones),
      preferencesKeyValueStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('starts on the phone’s own ringtone', () async {
    final container = _container(FakeRingtones(), InMemoryKeyValueStore());

    final ringtone = await container.read(callRingtoneProvider.future);

    expect(ringtone.title, 'Phone default');
    expect(ringtone.isDefault, isTrue);
    expect(ringtone.canChoose, isTrue);
  });

  test('remembers what was chosen', () async {
    final store = InMemoryKeyValueStore();
    final ringtones = FakeRingtones(
      chooses: const ChosenRingtone(uri: 'content://ringtone/7', title: 'Bell'),
      knownTitles: {'content://ringtone/7': 'Bell'},
    );
    final container = _container(ringtones, store);
    await container.read(callRingtoneProvider.future);

    await container.read(callRingtoneProvider.notifier).choose();

    expect(container.read(callRingtoneProvider).value?.title, 'Bell');
    expect(
      await store.read(CallRingtoneController.storageKey),
      'content://ringtone/7',
    );
  });

  test('backing out of the chooser keeps what was there', () async {
    final ringtones = FakeRingtones();
    final container = _container(ringtones, InMemoryKeyValueStore());
    final before = await container.read(callRingtoneProvider.future);

    await container.read(callRingtoneProvider.notifier).choose();

    expect(container.read(callRingtoneProvider).value?.title, before.title);
  });

  test(
    'a ringtone that has gone is forgotten, not left silently broken',
    () async {
      final store = InMemoryKeyValueStore();
      await store.write(
        CallRingtoneController.storageKey,
        'content://removed-sd-card/3',
      );
      // The phone no longer knows that address.
      final container = _container(FakeRingtones(), store);

      final ringtone = await container.read(callRingtoneProvider.future);

      expect(ringtone.isDefault, isTrue);
      expect(ringtone.title, 'Phone default');
      expect(await store.read(CallRingtoneController.storageKey), isNull);
    },
  );

  test('rings with the chosen sound, and stops', () async {
    final store = InMemoryKeyValueStore();
    await store.write(
      CallRingtoneController.storageKey,
      'content://ringtone/7',
    );
    final ringtones = FakeRingtones(
      knownTitles: {'content://ringtone/7': 'Bell'},
    );
    final container = _container(ringtones, store);
    await container.read(callRingtoneProvider.future);

    final controller = container.read(callRingtoneProvider.notifier);
    await controller.startRinging();

    expect(ringtones.playing, isTrue);
    expect(ringtones.playedUri, 'content://ringtone/7');

    await controller.stopRinging();
    expect(ringtones.playing, isFalse);
  });

  test('a phone with no chooser says so rather than offering one', () async {
    final container = ProviderContainer(
      overrides: [
        ringtonesProvider.overrideWithValue(const SilentRingtones()),
        preferencesKeyValueStoreProvider.overrideWithValue(
          InMemoryKeyValueStore(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final ringtone = await container.read(callRingtoneProvider.future);

    expect(ringtone.canChoose, isFalse);
  });
}
