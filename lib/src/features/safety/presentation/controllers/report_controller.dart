import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/server_config.dart';
import '../../../../core/config/server_config_providers.dart';
import '../../../../core/media/photo_processing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../chat/data/live_updates.dart';
import '../../../chat/domain/live_update.dart';
import '../../../matches/presentation/controllers/matches_controllers.dart';
import '../../data/safety_repository.dart';

/// Who is being reported, and what was on screen when the user chose to.
@immutable
final class ReportTarget {
  const ReportTarget({
    required this.userId,
    required this.displayName,
    this.matchId,
    this.context,
    this.contextId,
  });

  final String userId;
  final String displayName;

  /// Their match with the user, which blocking them ends.
  final String? matchId;

  final ReportContext? context;

  /// The message's id, when [context] is a message.
  final String? contextId;
}

/// How a report turned out, for the screen that opened the form.
enum ReportResult {
  reported,

  /// Reported and blocked, which also ended any match between them.
  reportedAndBlocked,
}

/// The reasons someone can be reported for, as the server lists them.
final reportReasonsProvider =
    FutureProvider.autoDispose<List<ReportReasonOption>>((ref) async {
      final reasons = (await ref.watch(
        serverConfigProvider.future,
      )).reportReasons;
      if (reasons.isEmpty) {
        throw const FormatException('The server listed no report reasons.');
      }
      return reasons;
    });

/// The report form as the user fills it in.
@immutable
final class ReportForm {
  const ReportForm({
    this.reason,
    this.details = '',
    this.alsoBlock = true,
    this.evidence = const [],
    this.isSubmitting = false,
    this.error,
  });

  /// The chosen reason's name in the API.
  final String? reason;

  final String details;

  /// Blocking is on unless the user turns it off: someone reporting another
  /// person usually doesn't want to hear from them again.
  final bool alsoBlock;

  final List<PreparedPhoto> evidence;
  final bool isSubmitting;

  /// Why the form can't be sent, in words for the user.
  final String? error;

  bool get canAddEvidence => evidence.length < ReportDraft.maxEvidence;

  ReportForm copyWith({
    String? reason,
    String? details,
    bool? alsoBlock,
    List<PreparedPhoto>? evidence,
    bool? isSubmitting,
    ValueGetter<String?>? error,
  }) {
    return ReportForm(
      reason: reason ?? this.reason,
      details: details ?? this.details,
      alsoBlock: alsoBlock ?? this.alsoBlock,
      evidence: evidence ?? this.evidence,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error == null ? this.error : error(),
    );
  }
}

/// The report form about the person with the given user id.
final reportFormProvider = NotifierProvider.autoDispose
    .family<ReportFormController, ReportForm, String>(ReportFormController.new);

class ReportFormController extends Notifier<ReportForm> {
  ReportFormController(this.userId);

  final String userId;

  @override
  ReportForm build() => const ReportForm();

  void selectReason(String reason) {
    state = state.copyWith(reason: reason, error: () => null);
  }

  void setDetails(String details) => state = state.copyWith(details: details);

  void setAlsoBlock(bool alsoBlock) {
    state = state.copyWith(alsoBlock: alsoBlock);
  }

  void addEvidence(PreparedPhoto photo) {
    if (!state.canAddEvidence) return;
    state = state.copyWith(evidence: [...state.evidence, photo]);
  }

  void removeEvidence(int index) {
    state = state.copyWith(
      evidence: [
        for (final (each, photo) in state.evidence.indexed)
          if (each != index) photo,
      ],
    );
  }

  /// Sends the report. Returns how it turned out, or `null` when it couldn't
  /// be sent, with [ReportForm.error] saying why.
  Future<ReportResult?> submit(ReportTarget target) async {
    final form = state;
    final reason = form.reason;
    if (form.isSubmitting) return null;
    if (reason == null) {
      state = form.copyWith(error: () => 'Choose what happened.');
      return null;
    }

    state = form.copyWith(isSubmitting: true, error: () => null);
    final updates = ref.read(liveUpdatesProvider);
    try {
      await ref
          .read(safetyRepositoryProvider)
          .report(
            ReportDraft(
              userId: target.userId,
              reason: reason,
              details: form.details,
              alsoBlock: form.alsoBlock,
              context: target.context,
              contextId: target.contextId,
              evidence: form.evidence,
            ),
          );
    } on ApiException catch (error) {
      if (ref.mounted) {
        state = state.copyWith(isSubmitting: false, error: () => error.message);
      }
      return null;
    }

    if (!form.alsoBlock) return ReportResult.reported;

    // Blocking ended any match between them, wherever it's listed.
    if (target.matchId case final matchId?) {
      updates.publish(MatchEnded(matchId));
    } else if (ref.mounted) {
      ref.invalidate(matchesListProvider);
    }
    return ReportResult.reportedAndBlocked;
  }
}
