import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/session_status.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/push/push_messaging.dart';
import '../../../core/push/push_providers.dart';
import '../../../core/realtime/realtime_connection.dart';
import '../../../core/realtime/realtime_providers.dart';
import '../../../core/widgets/app_messenger.dart';
import '../domain/app_notification.dart';
import '../domain/notification_target.dart';
import 'controllers/notifications_controllers.dart';
import 'notification_opener.dart';

/// How long a banner for a notification that arrived in the app stays up.
const pushBannerDuration = Duration(seconds: 5);

/// Handles push notifications for as long as the app runs: opens the one the
/// user tapped, whether that launched the app or brought it back, and shows
/// the ones arriving while the app is open as banners. Listen to this once.
final pushMessagesKeeperProvider = Provider<void>((ref) {
  final messaging = ref.watch(pushMessagingProvider);
  if (!messaging.isAvailable) return;
  final opener = ref.watch(notificationOpenerProvider);

  final opened = messaging.openedMessages.listen(
    (message) => unawaited(opener.openPush(message)),
  );
  final arrived = messaging.foregroundMessages.listen(
    (message) => _announce(ref, opener, message),
  );
  ref.onDispose(() {
    unawaited(opened.cancel());
    unawaited(arrived.cancel());
  });

  unawaited(() async {
    final launchedBy = await messaging.initialMessage();
    if (launchedBy == null || !ref.mounted) return;
    // Opening it needs the session, which is still being read at launch.
    await ref.read(sessionManagerProvider).ready;
    if (!ref.mounted || ref.read(sessionStatusProvider) is! SignedIn) return;
    await opener.openPush(launchedBy);
  }());
});

/// Shows [message], which arrived while the app is open, unless the user is
/// already looking at what it's about.
void _announce(Ref ref, NotificationOpener opener, PushMessage message) {
  if (ref.read(sessionStatusProvider) is! SignedIn) return;
  unawaited(ref.read(notificationUnreadCountProvider.notifier).refresh());

  final data = message.data;
  final category = NotificationCategory.fromWireValue(data['category'] ?? '');
  final target = NotificationTarget.of(category, data);

  final showing = ref.read(appRouterProvider).state.uri.path;
  if (target case OpenConversation(
    :final conversationId,
  ) when showing == AppRoutes.chat(conversationId)) {
    return;
  }
  // The live connection has already announced it.
  if (category == NotificationCategory.newMatch &&
      ref.read(realtimeStatusProvider) == RealtimeStatus.connected) {
    return;
  }

  final title = message.title?.trim() ?? '';
  final body = message.body?.trim() ?? '';
  final messenger = ref.read(appMessengerKeyProvider).currentState;
  if (messenger == null || (title.isEmpty && body.isEmpty)) return;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: pushBannerDuration,
        persist: false,
        content: PushBannerContent(title: title, body: body),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => unawaited(
            opener.open(target, notificationId: data['notification_id']),
          ),
        ),
      ),
    );
}

/// A notification's title and text, as a banner shows them.
class PushBannerContent extends StatelessWidget {
  const PushBannerContent({required this.title, required this.body, super.key});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        if (body.isNotEmpty)
          Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
