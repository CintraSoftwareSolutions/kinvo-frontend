import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';
import '../domain/verification.dart';

/// The account's identity check.
///
/// Failures are `ApiException`s.
abstract interface class VerificationRepository {
  /// What the account's verification looks like now, including the badge.
  Future<Verification> fetch();

  /// Starts an attempt. Refused with a 409 when one is already waiting.
  Future<Verification> start(VerificationMethod method);

  /// Attaches a finished upload as the document for [verificationId].
  Future<Verification> attachDocument({
    required String verificationId,
    required String uploadId,
  });

  /// Sends the attempt to be reviewed.
  Future<Verification> submit(String verificationId);
}

/// [VerificationRepository] on the Kinvo API.
final class ApiVerificationRepository implements VerificationRepository {
  const ApiVerificationRepository(this._api);

  final ApiClient _api;

  @override
  Future<Verification> fetch() {
    return _api.get('/verification', decode: Verification.fromJson);
  }

  @override
  Future<Verification> start(VerificationMethod method) {
    return _api.post(
      '/verification',
      body: {'method': method.wireValue},
      decode: Verification.fromJson,
    );
  }

  @override
  Future<Verification> attachDocument({
    required String verificationId,
    required String uploadId,
  }) {
    return _api.post(
      '/verification/${Uri.encodeComponent(verificationId)}/document',
      body: {'upload_id': uploadId},
      decode: Verification.fromJson,
    );
  }

  @override
  Future<Verification> submit(String verificationId) {
    return _api.post(
      '/verification/${Uri.encodeComponent(verificationId)}/submit',
      decode: Verification.fromJson,
    );
  }
}

/// The repository verification uses.
final verificationRepositoryProvider = Provider<VerificationRepository>((ref) {
  return ApiVerificationRepository(ref.watch(apiClientProvider));
});
