import 'dart:async';

import 'package:kinvo/src/core/push/app_icon_badge.dart';
import 'package:kinvo/src/core/push/push_messaging.dart';

/// Push notifications for tests: the permission, the token and incoming
/// notifications are all set by the test.
final class FakePushMessaging implements PushMessaging {
  FakePushMessaging({this.permissionState = PushPermission.granted});

  /// What the device currently allows.
  PushPermission permissionState;

  /// What the user answers when the system prompt is shown.
  PushPermission promptAnswer = PushPermission.granted;

  /// The notification that launched the app, if any.
  PushMessage? launchedBy;

  /// What asking the device about notifications throws, if anything, as
  /// when Firebase can't start.
  Exception? permissionFailure;

  int permissionRequests = 0;
  int tokensDeleted = 0;

  int _tokenNumber = 1;
  String? _token = 'fcm-token-1';

  final _refreshes = StreamController<String>.broadcast();
  final _arrivals = StreamController<PushMessage>.broadcast();
  final _taps = StreamController<PushMessage>.broadcast();

  /// The token the device holds now.
  String? get currentToken => _token;

  @override
  bool get isAvailable => true;

  @override
  Future<PushPermission> permission() async {
    if (permissionFailure case final failure?) throw failure;
    return permissionState;
  }

  @override
  Future<PushPermission> requestPermission() async {
    permissionRequests++;
    if (permissionFailure case final failure?) throw failure;
    if (permissionState == PushPermission.requestable) {
      permissionState = promptAnswer;
    }
    return permissionState;
  }

  @override
  Future<String?> token() async {
    return _token ??= 'fcm-token-${++_tokenNumber}';
  }

  @override
  Stream<String> get tokenRefreshes => _refreshes.stream;

  @override
  Future<void> deleteToken() async {
    tokensDeleted++;
    _token = null;
  }

  @override
  Stream<PushMessage> get foregroundMessages => _arrivals.stream;

  @override
  Stream<PushMessage> get openedMessages => _taps.stream;

  @override
  Future<PushMessage?> initialMessage() async => launchedBy;

  /// The platform replaces the token, as it does from time to time.
  void rotateToken() {
    final token = 'fcm-token-${++_tokenNumber}';
    _token = token;
    _refreshes.add(token);
  }

  /// [message] arrives while the app is open.
  void arrive(PushMessage message) => _arrivals.add(message);

  /// The user taps [message] while the app is in the background.
  void tap(PushMessage message) => _taps.add(message);
}

/// Records the numbers put on the app's icon.
final class RecordingAppIconBadge implements AppIconBadge {
  final List<int> shown = [];

  @override
  Future<void> show(int count) async => shown.add(count);
}
