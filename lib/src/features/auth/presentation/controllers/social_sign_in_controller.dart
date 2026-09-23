import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/google_identity.dart';
import '../../../../core/forms/form_errors.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/social_auth_service.dart';

/// Signing in with Google, from the button's point of view.
@immutable
final class SocialSignInState {
  const SocialSignInState({this.isBusy = false, this.error});

  /// True from the tap until Google and the server have both answered.
  final bool isBusy;

  /// What went wrong, in words, or null. Backing out of Google's own screen
  /// is not a failure and leaves this null.
  final String? error;
}

/// Shared by the sign-in and sign-up screens, because it is the same button
/// doing the same thing: a Google account with no Kinvo account gets one.
final socialSignInControllerProvider =
    NotifierProvider.autoDispose<SocialSignInController, SocialSignInState>(
      SocialSignInController.new,
    );

class SocialSignInController extends Notifier<SocialSignInState> {
  @override
  SocialSignInState build() => const SocialSignInState();

  /// Whether to offer Google at all. A build with no Google settings hides the
  /// button rather than failing when it is pressed.
  bool get canUseGoogle => ref.read(socialAuthServiceProvider).canUseGoogle;

  Future<void> signInWithGoogle() async {
    if (state.isBusy) return;
    state = const SocialSignInState(isBusy: true);

    String? error;
    try {
      await ref.read(socialAuthServiceProvider).signInWithGoogle();
      // Nothing to do on success: the session has started, and the router is
      // already moving to Discover or to onboarding.
    } on GoogleSignInRefused catch (refusal) {
      error = refusal.failure.message;
    } on ApiException catch (failure) {
      error = saveFailureMessage(failure);
    } finally {
      if (ref.mounted) state = SocialSignInState(error: error);
    }
  }

  /// Forgets the last error once it has been shown.
  void clearError() => state = const SocialSignInState();
}
