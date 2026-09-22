import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/forms/form_errors.dart';
import '../../../../core/media/media_uploader.dart';
import '../../../../core/media/photo_picker.dart';
import '../../../../core/media/photo_processing.dart';
import '../../../../core/network/api_error_code.dart';
import '../../../../core/network/api_exception.dart';
import '../../../profile/presentation/controllers/profile_controllers.dart';
import '../../data/verification_repository.dart';
import '../../domain/verification.dart';

/// What is happening on the verification screens that the server doesn't know
/// about: the document waiting to be sent, and whether something is in flight.
@immutable
final class VerificationDraft {
  const VerificationDraft({this.document, this.isBusy = false, this.error});

  /// The document as it was taken, kept only to show it back on this device.
  ///
  /// It is never fetched from the server: ID images live in a private bucket
  /// with a short-lived URL, and the app has no reason to read one back.
  final PreparedPhoto? document;

  final bool isBusy;

  /// What went wrong, in words, or null.
  final String? error;

  VerificationDraft copyWith({
    ValueGetter<PreparedPhoto?>? document,
    bool? isBusy,
    ValueGetter<String?>? error,
  }) {
    return VerificationDraft(
      document: document == null ? this.document : document(),
      isBusy: isBusy ?? this.isBusy,
      error: error == null ? this.error : error(),
    );
  }
}

final verificationDraftProvider =
    NotifierProvider<VerificationDraftController, VerificationDraft>(
      VerificationDraftController.new,
    );

class VerificationDraftController extends Notifier<VerificationDraft> {
  @override
  VerificationDraft build() => const VerificationDraft();

  void update(VerificationDraft Function(VerificationDraft draft) change) {
    state = change(state);
  }

  /// Forgets the last error once it has been shown.
  void clearError() => state = state.copyWith(error: () => null);
}

/// The account's identity check, and the three steps that change it.
///
/// Not auto-disposed: the attempt is started on one screen and finished on the
/// next two, and losing it in between would leave a half-finished record on
/// the server that the app had forgotten about.
final verificationProvider =
    AsyncNotifierProvider<VerificationController, Verification>(
      VerificationController.new,
    );

class VerificationController extends AsyncNotifier<Verification> {
  @override
  Future<Verification> build() {
    return ref.watch(verificationRepositoryProvider).fetch();
  }

  VerificationRepository get _verification =>
      ref.read(verificationRepositoryProvider);

  VerificationDraftController get _draft =>
      ref.read(verificationDraftProvider.notifier);

  /// Starts an attempt with [method]. Returns whether it went.
  Future<bool> start(VerificationMethod method) {
    return _run(() async {
      _draft.update((draft) => draft.copyWith(document: () => null));
      return _verification.start(method);
    });
  }

  /// Lets the user take or choose the document, then uploads it and attaches
  /// it to the attempt. Returns whether it went.
  ///
  /// The bytes go straight to storage and only the upload's id reaches this
  /// app's server, the same handshake profile photos use — so the picture is
  /// never in a request body or a log.
  Future<bool> chooseDocument(PhotoSource source) {
    return _run(() async {
      final current = state.value;
      if (current?.id case final verificationId?) {
        final picked = await ref.read(photoPickerProvider).pick(source);
        if (picked == null) return null;

        final uploadId = await ref
            .read(mediaUploaderProvider)
            .upload(
              purpose: UploadPurpose.verificationDocument,
              bytes: picked.bytes,
              mimeType: PreparedPhoto.mimeType,
            );

        final attached = await _verification.attachDocument(
          verificationId: verificationId,
          uploadId: uploadId,
        );
        _draft.update((draft) => draft.copyWith(document: () => picked));
        return attached;
      }
      return null;
    });
  }

  /// Sends the attempt to be reviewed. Returns whether it went.
  Future<bool> submit() {
    return _run(() async {
      final current = state.value;
      if (current?.id case final verificationId?) {
        final submitted = await _verification.submit(verificationId);
        // The document has done its job; there is no reason to keep a picture
        // of an ID in memory afterwards.
        _draft.update((draft) => draft.copyWith(document: () => null));
        return submitted;
      }
      return null;
    });
  }

  /// Re-reads the attempt, for coming back to the screen after a decision.
  Future<void> refresh() async {
    final latest = await AsyncValue.guard(_verification.fetch);
    if (ref.mounted) state = latest;
  }

  /// Runs one step, keeping the busy flag and the error message right.
  ///
  /// A step that returns null did nothing — the user cancelled the picker —
  /// and leaves the state alone.
  Future<bool> _run(Future<Verification?> Function() step) async {
    if (ref.read(verificationDraftProvider).isBusy) return false;
    _draft.update((draft) => draft.copyWith(isBusy: true, error: () => null));

    String? error;
    var done = false;
    try {
      final result = await step();
      if (result != null && ref.mounted) {
        state = AsyncData(result);
        // The badge shows on the profile as well, and that screen is the
        // one this was opened from.
        if (ref.exists(ownProfileProvider)) {
          ref.read(ownProfileProvider.notifier).refreshQuietly().ignore();
        }
      }
      done = result != null;
    } on PhotoPickException catch (failure) {
      error = failure.failure.message;
    } on ApiException catch (failure) {
      error = saveFailureMessage(failure);
      // The server and the app disagree about what is in progress — another
      // device, or an attempt this one forgot. Its answer is the true one.
      if (failure case ApiErrorException(code: ApiErrorCode.conflict)) {
        await refresh();
      }
    } finally {
      if (ref.mounted) {
        _draft.update(
          (draft) => draft.copyWith(isBusy: false, error: () => error),
        );
      }
    }
    return done;
  }
}
