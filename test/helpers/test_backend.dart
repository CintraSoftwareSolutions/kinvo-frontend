import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/ads/ads_platform.dart';
import 'package:kinvo/src/core/auth/google_identity.dart';
import 'package:kinvo/src/features/calls/presentation/call_notifications.dart';
import 'package:kinvo/src/core/auth/token_store.dart';
import 'package:kinvo/src/core/demo/demo_mode.dart';
import 'package:kinvo/src/core/device/client_info.dart';
import 'package:kinvo/src/core/device/device_providers.dart';
import 'package:kinvo/src/core/location/location_service.dart';
import 'package:kinvo/src/core/media/photo_picker.dart';
import 'package:kinvo/src/core/network/network_providers.dart';
import 'package:kinvo/src/core/push/push_messaging.dart';
import 'package:kinvo/src/core/push/push_providers.dart';
import 'package:kinvo/src/core/realtime/realtime_providers.dart';
import 'package:kinvo/src/core/ringtone/ringtone.dart';
import 'package:kinvo/src/core/storage/storage_providers.dart';
import 'package:kinvo/src/core/time/clock.dart';

import 'auth_fixtures.dart';
import 'device_fakes.dart';
import 'fake_http_adapter.dart';
import 'fake_push_messaging.dart';
import 'fake_realtime_server.dart';
import 'fake_call_notifications.dart';
import 'fake_ringtones.dart';
import 'in_memory_key_value_store.dart';

/// The device id sent with every request in tests.
const testDeviceId = 'test-device';

/// In-memory storage and a fake server, for running the app's real providers
/// in tests.
final class TestBackend {
  TestBackend({
    FakeResponder? respond,
    FakeRealtimeServer? realtime,
    PushMessaging? push,
    FakeCallNotifications? callNotifications,
    AdsPlatform? ads,
  }) : respond = respond ?? _notFound,
       ads = ads ?? const NoAdsPlatform(),
       realtime = realtime ?? FakeRealtimeServer(),
       push = push ?? const UnavailablePushMessaging(),
       callNotifications =
           callNotifications ?? FakeCallNotifications(available: false) {
    adapter = FakeHttpAdapter((options) => this.respond(options));
  }

  /// Answers every API request. Replace it to change what the server does.
  FakeResponder respond;

  /// The server's live connection.
  final FakeRealtimeServer realtime;

  /// Push notifications on the device. Unavailable unless a test supplies
  /// some, as in a build without Firebase settings.
  final PushMessaging push;

  /// The numbers the app put on its icon.
  final iconBadge = RecordingAppIconBadge();

  /// The phone this test rings with. Assert on it to check a call rang.
  final ringtones = FakeRingtones();

  /// The call screen the phone draws for itself. Off unless a test asks
  /// for one, as on a build with no push settings.
  final FakeCallNotifications callNotifications;

  /// Google's ad SDK. Off unless a test supplies a fake: no test may reach the
  /// real one, which needs a phone and the network.
  final AdsPlatform ads;

  final secureStore = InMemoryKeyValueStore();
  final preferences = InMemoryKeyValueStore();
  final photoPicker = FakePhotoPicker();
  final googleIdentity = FakeGoogleIdentity();
  final locationService = FakeLocationService();
  late final FakeHttpAdapter adapter;

  /// The saved session, as the app reads it at launch.
  TokenStore get tokenStore {
    return TokenStore(secureStore: secureStore, preferences: preferences);
  }

  /// Requests sent to [path], relative to the API base URL.
  Iterable<RequestOptions> requestsTo(String path) {
    return adapter.requests.where((r) => r.uri.path == '/api/v1$path');
  }

  /// Overrides that point the app's providers at this backend.
  ///
  /// [clock] fixes the time the app runs on; without it, the app uses the
  /// real clock.
  List<Override> overrides({bool demoAvailable = true, Clock? clock}) {
    return [
      secureKeyValueStoreProvider.overrideWithValue(secureStore),
      preferencesKeyValueStoreProvider.overrideWithValue(preferences),
      appConfigProvider.overrideWithValue(testConfig),
      // The real one reads the app version over a platform channel, which
      // never answers in tests.
      clientInfoProvider.overrideWithValue(
        const AsyncData(
          ClientInfo(
            deviceId: testDeviceId,
            platform: ClientPlatform.android,
            appVersion: '1.0.0+1',
          ),
        ),
      ),
      httpClientAdapterProvider.overrideWithValue(adapter),
      realtimeSocketFactoryProvider.overrideWithValue(realtime.createSocket),
      pushMessagingProvider.overrideWithValue(push),
      appIconBadgeProvider.overrideWithValue(iconBadge),
      // No test may reach the phone's ringtone chooser or make a sound.
      ringtonesProvider.overrideWithValue(ringtones),
      callNotificationsProvider.overrideWithValue(callNotifications),
      adsPlatformProvider.overrideWithValue(ads),
      demoModeAvailableProvider.overrideWithValue(demoAvailable),
      // The camera, photo library and location need a real device.
      photoPickerProvider.overrideWithValue(photoPicker),
      googleIdentityProvider.overrideWithValue(googleIdentity),
      locationServiceProvider.overrideWithValue(locationService),
      if (clock != null) clockProvider.overrideWithValue(clock),
    ];
  }

  /// A container running against this backend, disposed when the test ends.
  ProviderContainer createContainer({Clock? clock}) {
    return ProviderContainer.test(
      // Retries are covered by their own tests; here they would only delay
      // failures.
      retry: (_, _) => null,
      overrides: overrides(clock: clock),
    );
  }

  static Future<ResponseBody> _notFound(RequestOptions _) async {
    return jsonResponse(404, errorEnvelope('NOT_FOUND', 'Not found.'));
  }
}
