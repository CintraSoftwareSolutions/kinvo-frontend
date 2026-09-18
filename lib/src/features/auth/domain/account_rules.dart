import '../../../core/time/calendar_date.dart';

/// The backend's rules for account details, checked before sending so mistakes
/// show up straight away.
///
/// Mirrors `src/modules/auth/auth.schema.ts` and `src/utils/age.ts` in
/// kinvo-backend, messages included, so a problem reads the same whichever side
/// finds it. The server still decides: anything accepted here can be rejected
/// there, and its field errors are shown the same way. Keep both in step.
abstract final class AccountRules {
  static const minimumAge = 18;
  static const minPasswordLength = 8;
  static const maxPasswordLength = 72;
  static const maxDisplayNameLength = 50;
  static const maxEmailLength = 320;
  static const resetCodeLength = 6;

  /// The pattern zod 3 checks email addresses against. Using the server's own
  /// pattern means the app never refuses an address the server would accept.
  static final _emailPattern = RegExp(
    r"^(?!\.)(?!.*\.\.)([A-Z0-9_'+\-\.]*)[A-Z0-9_+-]@([A-Z0-9][A-Z0-9\-]*\.)+[A-Z]{2,}$",
    caseSensitive: false,
  );

  /// The code "forgot password" emails, as `resetPasswordSchema` requires it.
  static final _resetCodePattern = RegExp(r'^\d{6}$');

  static String? displayNameError(String displayName) {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return 'Enter your name.';
    if (trimmed.length > maxDisplayNameLength) {
      return 'Names can be at most $maxDisplayNameLength characters.';
    }
    return null;
  }

  static String? emailError(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return 'Enter your email address.';
    if (trimmed.length > maxEmailLength) {
      return 'That email address is too long.';
    }
    if (!_emailPattern.hasMatch(trimmed)) return 'Enter a valid email address.';
    return null;
  }

  /// For choosing a password. Only the length counts: rules about digits and
  /// symbols push people toward predictable passwords.
  static String? newPasswordError(String password) {
    if (password.isEmpty) return 'Enter a password.';
    if (password.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters.';
    }
    if (password.length > maxPasswordLength) {
      return 'Passwords can be at most $maxPasswordLength characters.';
    }
    return null;
  }

  /// For signing in, where the password is checked by the server alone.
  static String? passwordError(String password) {
    return password.isEmpty ? 'Enter your password.' : null;
  }

  /// The reset code from the email. Empty and malformed share one message: the
  /// user is copying six digits across, and "that isn't six digits" is the only
  /// thing worth saying about either.
  static String? resetCodeError(String code) {
    final trimmed = code.trim();
    if (!_resetCodePattern.hasMatch(trimmed)) {
      return 'Enter the $resetCodeLength-digit code from your email.';
    }
    return null;
  }

  /// Kinvo is for adults only. The server checks this again, against its own
  /// clock.
  static String? dateOfBirthError(
    CalendarDate? dateOfBirth, {
    required CalendarDate today,
  }) {
    if (dateOfBirth == null) return 'Enter your date of birth.';
    if (dateOfBirth.isAfter(today)) {
      return 'Date of birth cannot be in the future.';
    }
    if (dateOfBirth.yearsUntil(today) < minimumAge) {
      return 'You must be at least $minimumAge to use Kinvo.';
    }
    return null;
  }
}
