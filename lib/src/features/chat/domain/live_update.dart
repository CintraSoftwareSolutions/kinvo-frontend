import 'package:flutter/foundation.dart';

import '../../calls/domain/call.dart';
import '../../matches/domain/match_summary.dart';
import '../../profile/domain/user_summary.dart';
import 'chat_message.dart';

/// A change to the user's conversations or matches that screens showing them
/// should reflect straight away: from the server's live events, or from
/// something the user just did on this device.
@immutable
sealed class LiveUpdate {
  const LiveUpdate();
}

/// The other person in a conversation sent a message.
final class MessageReceived extends LiveUpdate {
  const MessageReceived(this.message);

  final ChatMessage message;
}

/// The other person in a conversation read it, up to [readAt].
final class ConversationRead extends LiveUpdate {
  const ConversationRead({
    required this.conversationId,
    required this.readerId,
    required this.readAt,
  });

  final String conversationId;
  final String readerId;
  final DateTime readAt;
}

/// The other person in a conversation started or stopped typing.
final class TypingChanged extends LiveUpdate {
  const TypingChanged({
    required this.conversationId,
    required this.userId,
    required this.isTyping,
  });

  final String conversationId;
  final String userId;
  final bool isTyping;
}

/// A conversation's last message, unread count or place in the lists
/// changed. Anything `null` didn't.
final class ConversationActivity extends LiveUpdate {
  const ConversationActivity({
    required this.conversationId,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.unreadCount,
    this.isArchived,
  });

  final String conversationId;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final int? unreadCount;

  /// Whether it's now in the Archived list rather than Matches.
  final bool? isArchived;
}

/// Someone the user matched with came online or went offline, or started or
/// stopped showing when they're active.
final class PresenceChanged extends LiveUpdate {
  const PresenceChanged({
    required this.userId,
    required this.isOnline,
    required this.lastActiveAt,
  });

  final String userId;
  final bool isOnline;

  /// `null` once they stop showing when they're active.
  final DateTime? lastActiveAt;
}

/// Someone liked the user back, and they matched.
final class MatchCreated extends LiveUpdate {
  const MatchCreated(this.match);

  final MatchSummary match;
}

/// A match changed on this device, such as being extended.
final class MatchChanged extends LiveUpdate {
  const MatchChanged(this.match);

  final MatchSummary match;
}

/// The user unmatched or blocked someone on this device, ending the match.
final class MatchEnded extends LiveUpdate {
  const MatchEnded(this.matchId);

  final String matchId;
}

/// The user's subscription changed, so what it unlocks may have too.
final class SubscriptionChanged extends LiveUpdate {
  const SubscriptionChanged();
}

/// A plan to meet one of the user's matches changed: suggested, answered,
/// changed or called off, on this device or by the other person. [planId] is
/// `null` when it isn't known which.
final class PlanUpdated extends LiveUpdate {
  const PlanUpdated({this.planId});

  final String? planId;
}

/// Someone is calling.
///
/// The same call also arrives as a push notification, because a phone with the
/// app closed has no socket. Both carry the same `callId`, so whichever gets
/// there first wins and the second is ignored.
final class CallIncoming extends LiveUpdate {
  const CallIncoming({
    required this.callId,
    required this.matchId,
    required this.mode,
    required this.kind,
    required this.from,
  });

  final String callId;
  final String matchId;
  final String mode;

  /// Video or voice. Answering a voice call must not open the camera, and this
  /// is the only thing the ringing phone has to go on.
  final CallKind kind;

  /// Who is calling, in the shape every list uses.
  final UserSummary from;
}

/// A call the user is in changed: answered, refused, or over.
final class CallChanged extends LiveUpdate {
  const CallChanged({
    required this.callId,
    required this.status,
    this.durationSeconds,
  });

  final String callId;
  final CallStatus status;

  /// How long the two were connected, when the server said. Null for a call
  /// that was never answered.
  final int? durationSeconds;
}
