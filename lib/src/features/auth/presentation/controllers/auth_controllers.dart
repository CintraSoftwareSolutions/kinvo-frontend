// The phone code screen is a prototype on sample data. Only demo builds lead
// to it; the real flow replaces this controller, as password reset already
// replaced its own.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final otpControllerProvider =
    NotifierProvider.autoDispose<OtpController, OtpState>(OtpController.new);

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

class OtpController extends Notifier<OtpState> {
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
