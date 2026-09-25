import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_uploader.dart';
import '../../../core/media/photo_processing.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';

/// What was being looked at when someone was reported, so moderators can find
/// it.
enum ReportContext {
  profile('profile'),
  message('message');

  const ReportContext(this.wireValue);

  final String wireValue;
}

/// A report, ready to send.
@immutable
final class ReportDraft {
  const ReportDraft({
    required this.userId,
    required this.reason,
    required this.details,
    required this.alsoBlock,
    this.context,
    this.contextId,
    this.evidence = const [],
  });

  /// Most screenshots a report can carry.
  static const maxEvidence = 5;

  /// Longest description the server accepts.
  static const maxDetailsLength = 1000;

  final String userId;

  /// The reason's name in the API, from the server's list.
  final String reason;

  /// What happened, in the user's words. Empty for none.
  final String details;

  /// Whether to block them in the same step.
  final bool alsoBlock;

  final ReportContext? context;

  /// The id of the message, when [context] is a message.
  final String? contextId;

  /// Screenshots or photos of what happened.
  final List<PreparedPhoto> evidence;
}

/// Blocking and reporting people.
///
/// Failures are `ApiException`s.
abstract interface class SafetyRepository {
  /// Blocks [userId]: neither sees the other again, and any match between them
  /// ends. Blocking someone already blocked succeeds.
  Future<void> block(String userId);

  /// Files [report]. Reports are anonymous: the person reported never learns
  /// who reported them.
  Future<void> report(ReportDraft report);
}

/// [SafetyRepository] on the Kinvo API.
final class ApiSafetyRepository implements SafetyRepository {
  const ApiSafetyRepository({
    required ApiClient api,
    required MediaUploader uploader,
  }) : _api = api,
       _uploader = uploader;

  final ApiClient _api;
  final MediaUploader _uploader;

  @override
  Future<void> block(String userId) {
    return _api.post(
      '/blocks',
      body: {'user_id': userId},
      decode: ApiClient.ignoreData,
    );
  }

  @override
  Future<void> report(ReportDraft report) async {
    // One at a time: on mobile data, parallel uploads mostly compete with
    // each other, and a report is rarely more than a screenshot or two.
    final evidenceIds = <String>[];
    for (final photo in report.evidence) {
      evidenceIds.add(
        await _uploader.upload(
          purpose: UploadPurpose.reportEvidence,
          bytes: photo.bytes,
          mimeType: PreparedPhoto.mimeType,
        ),
      );
    }

    final details = report.details.trim();
    await _api.post(
      '/reports',
      body: {
        'reported_id': report.userId,
        'reason': report.reason,
        if (details.isNotEmpty) 'description': details,
        'context_type': ?report.context?.wireValue,
        'context_id': ?report.contextId,
        'also_block': report.alsoBlock,
        if (evidenceIds.isNotEmpty) 'evidence_asset_ids': evidenceIds,
      },
      decode: ApiClient.ignoreData,
    );
  }
}

/// The repository safety actions use.
final safetyRepositoryProvider = Provider<SafetyRepository>((ref) {
  return ApiSafetyRepository(
    api: ref.watch(apiClientProvider),
    uploader: ref.watch(mediaUploaderProvider),
  );
});
