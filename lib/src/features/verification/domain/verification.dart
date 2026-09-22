import 'package:flutter/foundation.dart';

import '../../../core/network/api_envelope.dart';

/// How someone proves who they are.
///
/// `social` exists on the server and is deliberately not offered here: nothing
/// in the app links a social account, so submitting it would put a record with
/// no evidence in front of a moderator, who could only guess.
enum VerificationMethod {
  /// A selfie, checked against the profile photos.
  photo('photo'),

  /// A passport, driving licence or ID card.
  governmentId('government_id'),

  social('social');

  const VerificationMethod(this.wireValue);

  final String wireValue;

  /// The methods the app offers, in the order it offers them.
  static const offered = [photo, governmentId];

  static VerificationMethod? tryFromWireValue(String? value) {
    for (final method in values) {
      if (method.wireValue == value) return method;
    }
    return null;
  }
}

/// Where a verification has got to.
enum VerificationStatus {
  /// Never started, or the last attempt was rejected and cleared.
  notStarted('not_started'),

  /// Started. Whether it is waiting for a moderator or still waiting for the
  /// document is [Verification.isAwaitingReview].
  pending('pending'),

  approved('approved'),

  rejected('rejected');

  const VerificationStatus(this.wireValue);

  final String wireValue;

  static VerificationStatus fromWireValue(String value) {
    for (final status in values) {
      if (status.wireValue == value) return status;
    }
    // A status added to the server after this version of the app. Treating it
    // as "in progress" is the safe reading: it never claims a badge, and it
    // never offers to start a second attempt on top of one that exists.
    return pending;
  }
}

/// The account's identity check, from `GET /verification`.
@immutable
final class Verification {
  const Verification({
    required this.status,
    required this.isVerified,
    this.id,
    this.method,
    this.currentStep = 0,
    this.totalSteps = 3,
    this.submittedAt,
    this.reviewedAt,
    this.rejectionReason,
  });

  factory Verification.fromJson(JsonMap json) {
    if (json case {
      'id': final String? id,
      'method': final String? method,
      'status': final String status,
      'current_step': final int currentStep,
      'total_steps': final int totalSteps,
      'submitted_at': final String? submittedAt,
      'reviewed_at': final String? reviewedAt,
      'rejection_reason': final String? rejectionReason,
      'is_verified': final bool isVerified,
    }) {
      return Verification(
        id: id,
        method: VerificationMethod.tryFromWireValue(method),
        status: VerificationStatus.fromWireValue(status),
        currentStep: currentStep,
        totalSteps: totalSteps,
        submittedAt: DateTime.tryParse(submittedAt ?? ''),
        reviewedAt: DateTime.tryParse(reviewedAt ?? ''),
        rejectionReason: switch (rejectionReason?.trim()) {
          final String reason when reason.isNotEmpty => reason,
          _ => null,
        },
        isVerified: isVerified,
      );
    }
    throw const FormatException(
      'Expected a verification with id, method, status, current_step, '
      'total_steps, submitted_at, reviewed_at, rejection_reason and '
      'is_verified.',
    );
  }

  /// Nothing has been started yet.
  static const none = Verification(
    status: VerificationStatus.notStarted,
    isVerified: false,
  );

  /// The attempt this is about, or null when there has never been one.
  final String? id;

  final VerificationMethod? method;

  final VerificationStatus status;

  /// How far through the three steps the attempt got.
  final int currentStep;

  final int totalSteps;

  /// When it was sent to be reviewed, or null while it is still being filled
  /// in.
  final DateTime? submittedAt;

  final DateTime? reviewedAt;

  /// Why it was rejected, in the moderator's words. Only ever on your own
  /// record.
  final String? rejectionReason;

  /// Whether the account carries the badge. Comes from any approved attempt,
  /// not from [status], so it stays true while a later attempt is in progress.
  final bool isVerified;

  /// Waiting for a moderator: sent, and not yet decided.
  bool get isAwaitingReview =>
      status == VerificationStatus.pending && submittedAt != null;

  /// Started but not sent — the document is still missing, or was taken and
  /// not confirmed.
  bool get isUnfinished =>
      status == VerificationStatus.pending && submittedAt == null;

  /// Whether the document step has been done.
  bool get hasDocument => currentStep >= 2;

  /// Whether a fresh attempt can be started.
  bool get canStart => !isVerified && !isAwaitingReview && !isUnfinished;
}
