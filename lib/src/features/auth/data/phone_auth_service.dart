import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_api.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/device/client_info.dart';
import '../../../core/device/device_providers.dart';

/// Signing in with a phone number and a code sent by SMS.
///
/// The code never passes through this app's server: Twilio generates it, holds
/// it and checks it. So there is nothing here to store, nothing to expire, and
/// no code sitting in a database to be read.
///
/// A number with no account gets one, which is why this is both signing in and
/// signing up. That account has no date of birth, so the router sends it
/// straight to onboarding, where the first question is exactly that.
final class PhoneAuthService {
  PhoneAuthService({
    required AuthApi api,
    required SessionManager session,
    required Future<ClientInfo> Function() clientInfo,
  }) : _api = api,
       _session = session,
       _clientInfo = clientInfo;

  final AuthApi _api;
  final SessionManager _session;
  final Future<ClientInfo> Function() _clientInfo;

  /// Sends a code to [phone], which must be in international format.
  Future<void> sendCode(String phone) {
    return _api.sendPhoneCode(phone: normalisePhone(phone));
  }

  /// Signs in with the code. Returns true when the number had no account and
  /// one has just been created, which is what decides whether the app asks for
  /// a name and date of birth next.
  Future<bool> signIn({
    required String phone,
    required String code,
    String? displayName,
  }) async {
    final client = await _clientInfo();

    final result = await _api.verifyPhone(
      phone: normalisePhone(phone),
      code: code.trim(),
      deviceId: client.deviceId,
      displayName: displayName,
    );

    await _session.signIn(result.tokens);
    return result.isNewUser;
  }

  /// What the server accepts: a plus, then digits.
  ///
  /// People type numbers with spaces, brackets and dashes, and a number typed
  /// the way it is printed on a business card would otherwise be refused for
  /// looking wrong rather than being wrong. A leading `00` is the same thing
  /// as a plus in most of the world, so it is treated as one.
  static String normalisePhone(String input) {
    var trimmed = input.trim().replaceAll(RegExp(r'[\s()\-.]'), '');

    if (trimmed.startsWith('00')) {
      trimmed = '+${trimmed.substring(2)}';
    }

    return trimmed;
  }

  /// Whether [input] could be a phone number the server will accept, checked
  /// before sending so a typo costs no SMS.
  static bool looksValid(String input) {
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(normalisePhone(input));
  }
}

final phoneAuthServiceProvider = Provider<PhoneAuthService>((ref) {
  return PhoneAuthService(
    api: ref.watch(authApiProvider),
    session: ref.watch(sessionManagerProvider),
    clientInfo: () => ref.read(clientInfoProvider.future),
  );
});
