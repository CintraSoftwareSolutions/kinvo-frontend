import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final loginFormControllerProvider =
    NotifierProvider<LoginFormController, LoginFormState>(
      LoginFormController.new,
    );

final signupFormControllerProvider =
    NotifierProvider<SignupFormController, SignupFormState>(
      SignupFormController.new,
    );

final passwordResetControllerProvider =
    NotifierProvider<PasswordResetController, PasswordResetState>(
      PasswordResetController.new,
    );

final otpControllerProvider =
    AutoDisposeNotifierProvider<OtpController, OtpState>(OtpController.new);

class LoginFormState {
  const LoginFormState({
    required this.email,
    required this.password,
    required this.rememberDevice,
  });

  final String email;
  final String password;
  final bool rememberDevice;

  bool get canSubmit => email.trim().isNotEmpty && password.trim().isNotEmpty;

  LoginFormState copyWith({
    String? email,
    String? password,
    bool? rememberDevice,
  }) {
    return LoginFormState(
      email: email ?? this.email,
      password: password ?? this.password,
      rememberDevice: rememberDevice ?? this.rememberDevice,
    );
  }
}

class LoginFormController extends Notifier<LoginFormState> {
  @override
  LoginFormState build() {
    return const LoginFormState(
      email: 'alex@kinvo.app',
      password: 'password123',
      rememberDevice: true,
    );
  }

  void updateEmail(String value) => state = state.copyWith(email: value);

  void updatePassword(String value) => state = state.copyWith(password: value);

  void toggleRememberDevice(bool value) {
    state = state.copyWith(rememberDevice: value);
  }
}

class SignupFormState {
  const SignupFormState({
    required this.fullName,
    required this.email,
    required this.password,
    required this.primaryMode,
  });

  final String fullName;
  final String email;
  final String password;
  final String primaryMode;

  bool get canContinue =>
      fullName.trim().isNotEmpty &&
      email.trim().isNotEmpty &&
      password.trim().isNotEmpty;

  SignupFormState copyWith({
    String? fullName,
    String? email,
    String? password,
    String? primaryMode,
  }) {
    return SignupFormState(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      password: password ?? this.password,
      primaryMode: primaryMode ?? this.primaryMode,
    );
  }
}

class SignupFormController extends Notifier<SignupFormState> {
  @override
  SignupFormState build() {
    return const SignupFormState(
      fullName: 'Alex Johnson',
      email: 'alex@kinvo.app',
      password: 'password123',
      primaryMode: 'Dating',
    );
  }

  void updateFullName(String value) => state = state.copyWith(fullName: value);

  void updateEmail(String value) => state = state.copyWith(email: value);

  void updatePassword(String value) => state = state.copyWith(password: value);

  void selectPrimaryMode(String mode) {
    state = state.copyWith(primaryMode: mode);
  }
}

class PasswordResetState {
  const PasswordResetState({required this.email, required this.linkSent});

  final String email;
  final bool linkSent;

  bool get canSend => email.trim().isNotEmpty;

  PasswordResetState copyWith({String? email, bool? linkSent}) {
    return PasswordResetState(
      email: email ?? this.email,
      linkSent: linkSent ?? this.linkSent,
    );
  }
}

class PasswordResetController extends Notifier<PasswordResetState> {
  @override
  PasswordResetState build() {
    return const PasswordResetState(email: 'alex@kinvo.app', linkSent: false);
  }

  void updateEmail(String value) => state = state.copyWith(email: value);

  void sendResetLink() {
    state = state.copyWith(linkSent: true);
  }
}

class OtpState {
  const OtpState({required this.pin, required this.remainingSeconds});

  final String pin;
  final int remainingSeconds;

  bool get canVerify => pin.length == 6;

  String get formattedTime {
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  OtpState copyWith({String? pin, int? remainingSeconds}) {
    return OtpState(
      pin: pin ?? this.pin,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    );
  }
}

class OtpController extends AutoDisposeNotifier<OtpState> {
  Timer? _timer;

  @override
  OtpState build() {
    ref.onDispose(() => _timer?.cancel());
    _startTimer();
    return const OtpState(pin: '427189', remainingSeconds: 522);
  }

  void updatePin(String value) => state = state.copyWith(pin: value);

  void resendCode() {
    _timer?.cancel();
    state = state.copyWith(pin: '', remainingSeconds: 522);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds <= 0) {
        timer.cancel();
        return;
      }
      state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
    });
  }
}
