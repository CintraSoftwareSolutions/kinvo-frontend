import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/demo/demo_mode.dart';
import '../../../../core/media/photo_picker.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/network/api_error_code.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/widgets/flow_widgets.dart';
import '../../../../core/widgets/paywall_sheet.dart';
import '../../../../core/widgets/photo_source_sheet.dart';
import '../../../discovery/presentation/widgets/profile_sheet.dart';
import '../../../matches/presentation/controllers/matches_controllers.dart';
import '../../../modes/presentation/mode_presentation.dart';
import '../../../safety/data/safety_repository.dart';
import '../../../safety/presentation/controllers/report_controller.dart';
import '../controllers/chat_controller.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_header.dart';
import '../widgets/chat_menu_sheet.dart';
import '../widgets/chat_timeline.dart';
import '../widgets/closed_conversation_panel.dart';
import '../widgets/review_message_dialog.dart';

/// A conversation with a match.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _draft = TextEditingController();
  final _draftFocus = FocusNode();
  final _scroll = ScrollController();
  bool _isExtending = false;

  AsyncNotifierProvider<ChatController, ChatThread> get _provider {
    return chatControllerProvider(widget.conversationId);
  }

  ChatController get _chat => ref.read(_provider.notifier);

  @override
  void dispose() {
    _draft.dispose();
    _draftFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final thread = ref.watch(_provider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: switch (thread) {
          AsyncValue(value: final thread?) => _conversation(thread),
          AsyncValue(error: ApiErrorException(code: ApiErrorCode.notFound)) =>
            _Unavailable(onBack: _leave),
          AsyncValue(:final error?) => _Failed(
            message: error is ApiException
                ? error.message
                : 'Something went wrong. Please try again.',
            onBack: _leave,
            onRetry: () => ref.invalidate(_provider),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Widget _conversation(ChatThread thread) {
    final conversation = thread.conversation;
    final inDemo = ref.watch(demoSessionProvider);

    return Column(
      children: [
        ChatHeader(
          conversation: conversation,
          peerIsTyping: thread.peerIsTyping,
          onBack: _leave,
          onOpenProfile: () => _openProfile(thread),
          onOpenMenu: () => _openMenu(thread),
          // Calling isn't connected to the server yet; the demo shows how it
          // will look.
          onVideoCall: inDemo
              ? () => context.push(AppRoutes.videoCall(widget.conversationId))
              : null,
        ),
        const Divider(height: 1, color: AppColors.divider),
        Expanded(
          child: ChatTimeline(
            thread: thread,
            now: ref.watch(clockProvider)(),
            scrollController: _scroll,
            onLoadOlder: _chat.loadOlder,
            onOutgoingTap: _offerRetry,
            onQuickReply: (reply) {
              _draft.text = reply;
              _draftFocus.requestFocus();
            },
          ),
        ),
        if (conversation.isWritable)
          ChatComposer(
            controller: _draft,
            focusNode: _draftFocus,
            onChanged: _chat.draftChanged,
            onSend: _send,
            onAttachPhoto: _attachPhoto,
          )
        else
          ClosedConversationPanel(
            matchId: conversation.matchId,
            isExtending: _isExtending,
            onExtend: _extend,
          ),
      ],
    );
  }

  Future<void> _send() async {
    final text = _draft.text;
    if (text.trim().isEmpty) return;
    _draft.clear();
    _showNewest();
    await _handleSend(await _chat.send(text));
  }

  Future<void> _handleSend(SendOutcome outcome) async {
    if (!mounted) return;
    switch (outcome) {
      case SendNeedsReview(:final text, :final check):
        final choice = await showReviewMessageDialog(
          context,
          text: text,
          warnings: check.warnings,
        );
        if (!mounted) return;
        if (choice == ReviewChoice.sendAnyway) {
          _showNewest();
          await _handleSend(await _chat.send(text, reviewed: true));
        } else if (_draft.text.trim().isEmpty) {
          // Back in the box to change, where the user left it.
          _draft.text = text;
          _draftFocus.requestFocus();
        }
      case SendNeedsUpgrade(:final paywall):
        await showPaywallSheet(context, paywall);
      case SendRefused():
        _say("This conversation is closed, so the message wasn't sent.");
      case Sent() || NothingToSend() || SendFailed():
        // A failed message says so where it sits, with a way to try again.
        break;
    }
  }

  Future<void> _attachPhoto() async {
    final source = await showPhotoSourceSheet(context);
    if (source == null || !mounted) return;
    try {
      final photo = await ref.read(photoPickerProvider).pick(source);
      if (photo == null || !mounted) return;
      _showNewest();
      await _handleSend(await _chat.sendPhoto(photo));
    } on PhotoPickException catch (error) {
      _say(error.failure.message);
    }
  }

  Future<void> _offerRetry(OutgoingMessage outgoing) async {
    final retry = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('Try again'),
                onTap: () => Navigator.of(sheet).pop(true),
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                ),
                title: const Text(
                  'Delete message',
                  style: TextStyle(color: AppColors.danger),
                ),
                onTap: () => Navigator.of(sheet).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
    if (retry == null || !mounted) return;
    if (retry) {
      await _handleSend(await _chat.retry(outgoing.localId));
    } else {
      _chat.discard(outgoing.localId);
    }
  }

  Future<void> _openProfile(ChatThread thread) {
    final conversation = thread.conversation;
    return showProfileSheet<void>(
      context,
      user: conversation.user,
      accent: modeColors(conversation.mode).primary,
    );
  }

  Future<void> _openMenu(ChatThread thread) async {
    final conversation = thread.conversation;
    final now = ref.read(clockProvider)();
    final expiresSoon =
        conversation.matchExpiresAt.difference(now) < extendOfferWithin;

    final action = await showChatMenuSheet(
      context,
      name: conversation.user.displayName,
      actions: [
        ChatMenuAction.viewProfile,
        if (conversation.isWritable) ...[
          ChatMenuAction.suggestPlan,
          conversation.isMuted ? ChatMenuAction.unmute : ChatMenuAction.mute,
          if (expiresSoon) ChatMenuAction.extend,
        ],
        conversation.isArchived
            ? ChatMenuAction.unarchive
            : ChatMenuAction.archive,
        ChatMenuAction.report,
        if (conversation.isWritable) ChatMenuAction.unmatch,
        ChatMenuAction.block,
      ],
    );
    if (action == null || !mounted) return;

    final name = conversation.user.displayName;
    switch (action) {
      case ChatMenuAction.viewProfile:
        await _openProfile(thread);
      case ChatMenuAction.suggestPlan:
        await context.push(AppRoutes.planWith(conversation.matchId));
      case ChatMenuAction.mute || ChatMenuAction.unmute:
        final mute = action == ChatMenuAction.mute;
        final error = await _chat.setMuted(mute);
        _say(
          error ??
              (mute
                  ? "You won't be notified about new messages from $name."
                  : "You'll be notified about new messages from $name."),
        );
      case ChatMenuAction.archive || ChatMenuAction.unarchive:
        final archive = action == ChatMenuAction.archive;
        final error = await _chat.setArchived(archive);
        _say(error ?? (archive ? 'Moved to Archived.' : 'Moved to Matches.'));
      case ChatMenuAction.extend:
        await _extend();
      case ChatMenuAction.report:
        await _report(thread);
      case ChatMenuAction.unmatch:
        final confirmed = await _confirm(
          title: 'Unmatch $name?',
          message:
              "You won't be able to message each other, and this can't be "
              'undone.',
          action: 'Unmatch',
        );
        if (!confirmed) return;
        final error = await _chat.unmatch();
        if (error != null) {
          _say(error);
          return;
        }
        _say('You unmatched $name.');
        _leave();
      case ChatMenuAction.block:
        final confirmed = await _confirm(
          title: 'Block $name?',
          message:
              "You won't see each other anywhere on Kinvo, and your match "
              "ends. $name isn't told.",
          action: 'Block',
        );
        if (!confirmed) return;
        final error = await _chat.block();
        if (error != null) {
          _say(error);
          return;
        }
        _say('You blocked $name.');
        _leave();
    }
  }

  Future<void> _report(ChatThread thread) async {
    final conversation = thread.conversation;
    // Their latest message tells moderators where to look.
    final theirLatest = thread.messages
        .where((message) => !thread.isMine(message))
        .firstOrNull;

    final result = await context.push<ReportResult>(
      AppRoutes.reportPath,
      extra: ReportTarget(
        userId: conversation.user.id,
        displayName: conversation.user.displayName,
        matchId: conversation.matchId,
        context: theirLatest == null
            ? ReportContext.profile
            : ReportContext.message,
        contextId: theirLatest?.id,
      ),
    );
    if (result == null || !mounted) return;

    switch (result) {
      case ReportResult.reported:
        _say('Thanks for telling us. Our team will look into it.');
      case ReportResult.reportedAndBlocked:
        _chat.reportedAndBlocked();
        _say(
          "Thanks for telling us. You won't see "
          '${conversation.user.displayName} again.',
        );
        _leave();
    }
  }

  Future<void> _extend() async {
    setState(() => _isExtending = true);
    final outcome = await _chat.extend();
    if (!mounted) return;
    setState(() => _isExtending = false);

    switch (outcome) {
      case Extended(:final match):
        final until = MaterialLocalizations.of(
          context,
        ).formatMediumDate(match.expiresAt.toLocal());
        _say('Extended until $until.');
      case ExtendNeedsUpgrade(:final paywall):
        await showPaywallSheet(context, paywall);
      case ExtendFailed(:final message):
        _say(message);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(action),
          ),
        ],
      ),
    );
    return (confirmed ?? false) && mounted;
  }

  /// Scrolls to the newest message, where anything just sent appears.
  void _showNewest() {
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.jumpTo(0);
    }
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.matches);
    }
  }

  /// Shows [message] in the app's snackbar, which outlives this screen.
  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return _CenteredMessage(
      title: "This conversation isn't available",
      message: 'It may have ended, or the link may be wrong.',
      actionLabel: 'Back to matches',
      onAction: onBack,
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({
    required this.message,
    required this.onBack,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: HeaderCircleButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onTap: onBack,
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: _CenteredMessage(
            title: "The conversation didn't load",
            message: message,
            actionLabel: 'Try again',
            onAction: onRetry,
          ),
        ),
      ],
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            PrimaryActionButton(
              label: actionLabel,
              borderRadius: 999,
              onPressed: onAction,
            ),
          ],
        ),
      ),
    );
  }
}
