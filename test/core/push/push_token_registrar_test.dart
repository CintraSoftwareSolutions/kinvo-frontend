import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/push/push_messaging.dart';
import 'package:kinvo/src/core/push/push_providers.dart';
import 'package:kinvo/src/core/push/push_token_registrar.dart';

import '../../helpers/fake_kinvo_server.dart';
import '../../helpers/fake_push_messaging.dart';
import '../../helpers/test_backend.dart';

void main() {
  late FakeKinvoServer server;
  late FakePushMessaging push;
  late TestBackend backend;
  late ProviderContainer container;

  PushTokenRegistrar registrar() => container.read(pushTokenRegistrarProvider);

  setUp(() {
    server = FakeKinvoServer()
      ..completeProfile()
      ..isOnboarded = true;
    push = FakePushMessaging();
    backend = TestBackend(respond: server.respond, push: push);
    container = backend.createContainer();
  });

  test('registers this device when notifications are allowed', () async {
    await registrar().sync();

    expect(server.pushTokens, {testDeviceId: 'fcm-token-1'});
  });

  test('registers a token once, however often it syncs', () async {
    await registrar().sync();
    await registrar().sync();

    expect(backend.requestsTo('/notifications/tokens'), hasLength(1));
  });

  test('registers again when the token changes', () async {
    await registrar().sync();

    push.rotateToken();
    await registrar().sync();

    expect(server.pushTokens, {testDeviceId: 'fcm-token-2'});
  });

  test('tells the server to stop when notifications are not allowed', () async {
    await registrar().sync();
    push.permissionState = PushPermission.blocked;

    await registrar().sync();
    await registrar().sync();

    expect(server.pushTokens, isEmpty);
    // Once is enough.
    expect(server.pushTokensRemoved, [testDeviceId]);
  });

  test('registers again once notifications are allowed again', () async {
    push.permissionState = PushPermission.requestable;
    await registrar().sync();

    push.permissionState = PushPermission.granted;
    await registrar().sync();

    expect(server.pushTokens, {testDeviceId: 'fcm-token-1'});
  });

  test('throws the token away when the session ends, so the next account '
      'gets its own', () async {
    await registrar().sync();

    await registrar().signedOut();
    expect(push.tokensDeleted, 1);

    await registrar().sync();
    expect(server.pushTokens, {testDeviceId: 'fcm-token-2'});
  });

  test('tries again next time when the server could not be reached', () async {
    var offline = true;
    server.intercept = (options) async {
      if (offline && options.path.endsWith('/notifications/tokens')) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const SocketException('Network is unreachable'),
        );
      }
      return null;
    };

    await registrar().sync();
    expect(server.pushTokens, isEmpty);

    offline = false;
    await registrar().sync();
    expect(server.pushTokens, {testDeviceId: 'fcm-token-1'});
  });

  test('does nothing in a build without push notifications', () async {
    final unavailable = TestBackend(respond: server.respond);
    final plain = unavailable.createContainer();

    await plain.read(pushTokenRegistrarProvider).sync();
    await plain.read(pushTokenRegistrarProvider).signedOut();

    expect(unavailable.adapter.requests, isEmpty);
  });
}
