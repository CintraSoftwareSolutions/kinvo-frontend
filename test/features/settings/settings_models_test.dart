import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/units/distance.dart';
import 'package:kinvo/src/features/settings/domain/signed_in_device.dart';
import 'package:kinvo/src/features/settings/domain/user_settings.dart';
import 'package:kinvo/src/features/settings/presentation/screens/devices_screen.dart';

Map<String, Object?> _settings({
  String unit = 'kilometres',
  bool snoozed = false,
  String? endsAt,
}) {
  return {
    'theme': 'system',
    'text_scale': 1.0,
    'reduce_motion': false,
    'high_contrast': false,
    'distance_unit': unit,
    'show_distance': false,
    'show_last_active': true,
    'incognito': false,
    'global_verified_only': false,
    'pause_new_matches': false,
    'language': 'en',
    'snooze': {'is_snoozed': snoozed, 'ends_at': endsAt},
    'updated_at': '2026-09-15T10:00:00.000Z',
  };
}

void main() {
  group('settings', () {
    test('are read from GET /settings', () {
      final settings = UserSettings.fromJson(_settings());

      expect(settings.distanceUnit, DistanceUnit.kilometres);
      expect(settings.showDistance, isFalse);
      expect(settings.showLastActive, isTrue);
      expect(settings.isOnBreak, isFalse);
    });

    test('say when a break ends, or that it lasts until the user is back', () {
      final timed = UserSettings.fromJson(
        _settings(snoozed: true, endsAt: '2026-09-20T10:00:00.000Z'),
      );
      final open = UserSettings.fromJson(_settings(snoozed: true));

      expect(timed.snooze?.endsAt, DateTime.utc(2026, 9, 20, 10));
      expect(open.isOnBreak, isTrue);
      expect(open.snooze?.endsAt, isNull);
    });

    test('show a unit this app does not know in miles', () {
      expect(
        UserSettings.fromJson(_settings(unit: 'leagues')).distanceUnit,
        DistanceUnit.miles,
      );
    });

    test('change without losing the break', () {
      final settings = UserSettings.fromJson(_settings(snoozed: true));

      final changed = settings.copyWith(showLastActive: false);

      expect(changed.showLastActive, isFalse);
      expect(changed.isOnBreak, isTrue);
      expect(changed.distanceUnit, DistanceUnit.kilometres);
    });

    test('fail without the fields the app uses', () {
      expect(
        () => UserSettings.fromJson({'distance_unit': 'miles'}),
        throwsFormatException,
      );
    });
  });

  group('a signed-in device', () {
    Map<String, Object?> device({String? model, String platform = 'ios'}) {
      return {
        'id': 'd1',
        'device_id': 'install-1',
        'platform': platform,
        'app_version': '1.0.0+1',
        'os_version': 'iOS 18.1',
        'model': model,
        'is_current': true,
        'last_seen_at': '2026-09-17T09:00:00.000Z',
        'created_at': '2026-09-01T10:00:00.000Z',
      };
    }

    test('is read from GET /devices', () {
      final signedIn = SignedInDevice.tryFromJson(
        device(model: 'iPhone 15 Pro'),
      );

      expect(signedIn?.name, 'iPhone 15 Pro');
      expect(signedIn?.osVersion, 'iOS 18.1');
      expect(signedIn?.isCurrent, isTrue);
      expect(signedIn?.lastSeenAt, DateTime.utc(2026, 9, 17, 9));
    });

    test('is named by its kind when the model is not known', () {
      expect(SignedInDevice.tryFromJson(device())?.name, 'iPhone or iPad');
      expect(
        SignedInDevice.tryFromJson(
          device(platform: 'android', model: ' '),
        )?.name,
        'Android device',
      );
    });

    test('is left out when malformed', () {
      expect(SignedInDevice.tryFromJson({'id': 'd1'}), isNull);
      expect(
        SignedInDevice.tryFromJson({...device(), 'last_seen_at': 'soon'}),
        isNull,
      );
    });

    test('says when it was last used, in days', () {
      final now = DateTime(2026, 9, 17, 18);
      String label(DateTime seen) => deviceActivityLabel(
        seen,
        now: now,
        formatDay: (day) => '${day.day}/${day.month}',
      );

      expect(label(DateTime(2026, 9, 17, 8)), 'Active today');
      expect(label(DateTime(2026, 9, 16, 23)), 'Active yesterday');
      expect(label(DateTime(2026, 9, 14, 12)), 'Active 3 days ago');
      expect(label(DateTime(2026, 9, 2, 12)), 'Active on 2/9');
    });
  });
}
