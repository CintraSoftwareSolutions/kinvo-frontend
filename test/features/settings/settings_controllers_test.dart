import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/auth/auth_providers.dart';
import 'package:kinvo/src/core/network/api_exception.dart';
import 'package:kinvo/src/core/units/distance.dart';
import 'package:kinvo/src/features/settings/domain/signed_in_device.dart';
import 'package:kinvo/src/features/settings/domain/user_settings.dart';
import 'package:kinvo/src/features/settings/presentation/controllers/settings_controllers.dart';

import '../../helpers/app_harness.dart';
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

  Future<UserSettings> settings() {
    container.listen(userSettingsProvider, (_, _) {});
    return container.read(userSettingsProvider.future);
  }

  UserSettingsController controller() {
    return container.read(userSettingsProvider.notifier);
  }

  UserSettings? current() => container.read(userSettingsProvider).value;

  test('reads the settings, and the unit every distance uses', () async {
    server.distanceUnit = 'kilometres';
    container.listen(distanceUnitProvider, (_, _) {});
    expect(container.read(distanceUnitProvider), DistanceUnit.miles);

    await settings();

    expect(current()?.distanceUnit, DistanceUnit.kilometres);
    expect(container.read(distanceUnitProvider), DistanceUnit.kilometres);
  });

  test('changes a setting at once, and keeps it once saved', () async {
    await settings();

    final saving = controller().change(showDistance: false);
    expect(current()?.showDistance, isFalse);
    await saving;

    expect(server.showDistance, isFalse);
    expect(backend.requestsTo('/settings').last.data, {'show_distance': false});
  });

  test('puts a setting back when the server refuses it', () async {
    await settings();
    server.intercept = (options) async {
      if (options.method == 'PATCH' && options.path.endsWith('/settings')) {
        return jsonResponse(
          503,
          errorEnvelope('SERVICE_UNAVAILABLE', 'Please try again shortly.'),
        );
      }
      return null;
    };

    await expectLater(
      controller().change(showLastActive: false),
      throwsA(isA<ApiException>()),
    );

    expect(current()?.showLastActive, isTrue);
    expect(server.showLastActive, isTrue);
  });

  test('takes a break for a set time', () async {
    await settings();

    await controller().takeBreak(duration: const Duration(days: 7));

    final endsAt = server.now().add(const Duration(days: 7));
    expect(server.isSnoozed, isTrue);
    expect(server.snoozeEndsAt, endsAt);
    expect(current()?.snooze?.endsAt, endsAt);
  });

  test('takes a break until the user comes back, then ends it', () async {
    await settings();

    await controller().takeBreak();
    expect(backend.requestsTo('/settings/snooze').single.data, isEmpty);
    expect(current()?.isOnBreak, isTrue);
    expect(current()?.snooze?.endsAt, isNull);

    await controller().endBreak();
    expect(server.isSnoozed, isFalse);
    expect(current()?.isOnBreak, isFalse);
  });

  group('devices', () {
    setUp(() {
      server.devices.addAll([
        FakeDevice(
          id: 'row-this',
          deviceId: testDeviceId,
          model: 'Google Pixel 8',
          lastSeenAt: server.now(),
        ),
        FakeDevice(
          id: 'row-tablet',
          deviceId: 'tablet',
          platform: 'ios',
          model: 'iPad Air',
          lastSeenAt: server.now().subtract(const Duration(days: 2)),
        ),
        FakeDevice(
          id: 'row-old',
          deviceId: 'old-phone',
          lastSeenAt: server.now().subtract(const Duration(days: 30)),
        ),
      ]);
    });

    Future<List<SignedInDevice>> devices() {
      container.listen(signedInDevicesProvider, (_, _) {});
      return container.read(signedInDevicesProvider.future);
    }

    List<String> shown() => [
      for (final device in container.read(signedInDevicesProvider).value!)
        device.id,
    ];

    test('lists them, most recent first, with this one marked', () async {
      final listed = await devices();

      expect(listed.map((device) => device.id), [
        'row-this',
        'row-tablet',
        'row-old',
      ]);
      expect(listed.first.isCurrent, isTrue);
      expect(listed.skip(1).any((device) => device.isCurrent), isFalse);
    });

    test('signs one out', () async {
      await devices();

      await container.read(signedInDevicesProvider.notifier).signOut('row-old');

      expect(server.devicesSignedOut, ['old-phone']);
      expect(shown(), ['row-this', 'row-tablet']);
    });

    test('signs out every other device', () async {
      await devices();

      final count = await container
          .read(signedInDevicesProvider.notifier)
          .signOutOthers();

      expect(count, 2);
      expect(server.devicesSignedOut, ['tablet', 'old-phone']);
      expect(shown(), ['row-this']);
    });

    test('shows what the server has when a sign-out fails', () async {
      await devices();

      await expectLater(
        container.read(signedInDevicesProvider.notifier).signOut('row-gone'),
        throwsA(isA<ApiErrorException>()),
      );
      await container.read(signedInDevicesProvider.future);

      expect(shown(), ['row-this', 'row-tablet', 'row-old']);
    });
  });
}
