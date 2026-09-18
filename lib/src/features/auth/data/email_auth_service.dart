import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_api.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/device/client_info.dart';
import '../../../core/device/device_providers.dart';
import '../../../core/time/calendar_date.dart';

/// Creates accounts and signs in with an email address and password.
///
/// Both start a session through [SessionManager], and the router follows it
/// into the app. Failures are `ApiException`s and leave the user signed out.
final class EmailAuthService {
  EmailAuthService({
    required AuthApi api,
    required SessionManager session,
    required Future<ClientInfo> Function() clientInfo,
  }) : _api = api,
       _session = session,
       _clientInfo = clientInfo;

  final AuthApi _api;
  final SessionManager _session;
  final Future<ClientInfo> Function() _clientInfo;

  /// Creates an account and signs in to it.
  ///
  /// The name and email are sent without surrounding spaces; the password is
  /// sent exactly as typed.
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
    required CalendarDate dateOfBirth,
  }) async {
    final client = await _clientInfo();
    final tokens = await _api.register(
      displayName: displayName.trim(),
      email: email.trim(),
      password: password,
      dateOfBirth: dateOfBirth,
      deviceId: client.deviceId,
    );
    await _session.signIn(tokens);
  }

  /// Signs in to an existing account. When [remember] is false, the session
  /// ends when the app closes.
  Future<void> login({
    required String email,
    required String password,
    required bool remember,
  }) async {
    final client = await _clientInfo();
    final tokens = await _api.login(
      email: email.trim(),
      password: password,
      deviceId: client.deviceId,
    );
    await _session.signIn(tokens, remember: remember);
  }
}

final emailAuthServiceProvider = Provider<EmailAuthService>((ref) {
  return EmailAuthService(
    api: ref.watch(authApiProvider),
    session: ref.watch(sessionManagerProvider),
    clientInfo: () => ref.read(clientInfoProvider.future),
  );
});
