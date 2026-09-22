import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo/demo_mode.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';
import '../../../core/time/clock.dart';
import '../domain/verification.dart';

/// The account's identity check.
///
/// An interface because the demo shows the same screens without an account, on
/// [DemoVerificationRepository]. Failures are `ApiException`s.
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

/// What the demo remembers about verification, for as long as the demo lasts.
final class DemoVerification {
  DemoVerification({required this.clock});

  final Clock clock;

  Verification current = Verification.none;
}

final demoVerificationProvider = Provider<DemoVerification>((ref) {
  ref.watch(demoSessionProvider);
  return DemoVerification(clock: ref.watch(clockProvider));
});

/// [VerificationRepository] for the demo: the attempt is kept in memory and
/// nothing is sent anywhere.
///
/// It stops at "waiting for review", as the real one does. A demo that handed
/// out the badge would be showing something the product cannot do on its own:
/// a person decides.
final class DemoVerificationRepository implements VerificationRepository {
  const DemoVerificationRepository(this._demo);

  final DemoVerification _demo;

  @override
  Future<Verification> fetch() async => _demo.current;

  @override
  Future<Verification> start(VerificationMethod method) async {
    return _demo.current = Verification(
      id: 'demo-verification',
      method: method,
      status: VerificationStatus.pending,
      currentStep: 1,
      isVerified: false,
    );
  }

  @override
  Future<Verification> attachDocument({
    required String verificationId,
    required String uploadId,
  }) async {
    return _demo.current = Verification(
      id: verificationId,
      method: _demo.current.method,
      status: VerificationStatus.pending,
      currentStep: 2,
      isVerified: false,
    );
  }

  @override
  Future<Verification> submit(String verificationId) async {
    return _demo.current = Verification(
      id: verificationId,
      method: _demo.current.method,
      status: VerificationStatus.pending,
      currentStep: 3,
      submittedAt: _demo.clock(),
      isVerified: false,
    );
  }
}

/// The repository verification uses: the demo's while exploring it, the API's
/// otherwise.
final verificationRepositoryProvider = Provider<VerificationRepository>((ref) {
  if (ref.watch(demoSessionProvider)) {
    return DemoVerificationRepository(ref.watch(demoVerificationProvider));
  }
  return ApiVerificationRepository(ref.watch(apiClientProvider));
});
