import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/time/calendar_date.dart';
import 'package:kinvo/src/features/auth/domain/account_rules.dart';

void main() {
  group('email', () {
    test('is required', () {
      expect(AccountRules.emailError(''), 'Enter your email address.');
      expect(AccountRules.emailError('   '), 'Enter your email address.');
    });

    test('accepts ordinary addresses, ignoring surrounding spaces', () {
      for (final email in [
        'sam@example.com',
        ' Sam.Taylor+kinvo@mail.example.co.uk ',
        "o'neil@example.org",
      ]) {
        expect(AccountRules.emailError(email), isNull, reason: email);
      }
    });

    test('refuses what the server refuses', () {
      for (final email in [
        'sam',
        'sam@',
        '@example.com',
        'sam@example',
        'sam@example.c',
        '.sam@example.com',
        'sam.@example.com',
        'sam..taylor@example.com',
        'sam taylor@example.com',
        'sam@exam_ple.com',
      ]) {
        expect(
          AccountRules.emailError(email),
          'Enter a valid email address.',
          reason: email,
        );
      }
    });

    test('is at most 320 characters', () {
      final longest = '${'a' * 64}@${'b' * 251}.com';
      expect(longest, hasLength(320));

      expect(AccountRules.emailError(longest), isNull);
      expect(
        AccountRules.emailError('a$longest'),
        'That email address is too long.',
      );
    });
  });

  test('a new password has 8 to 72 characters, spaces included', () {
    expect(AccountRules.newPasswordError(''), 'Enter a password.');
    expect(
      AccountRules.newPasswordError('1234567'),
      'Use at least 8 characters.',
    );
    expect(AccountRules.newPasswordError(' ' * 8), isNull);
    expect(AccountRules.newPasswordError('a' * 72), isNull);
    expect(
      AccountRules.newPasswordError('a' * 73),
      'Passwords can be at most 72 characters.',
    );
  });

  test('a password to sign in with only has to be entered', () {
    expect(AccountRules.passwordError(''), 'Enter your password.');
    expect(AccountRules.passwordError('x'), isNull);
  });

  test('a name is required and at most 50 characters', () {
    expect(AccountRules.displayNameError('  '), 'Enter your name.');
    expect(AccountRules.displayNameError('  ${'a' * 50}  '), isNull);
    expect(
      AccountRules.displayNameError('a' * 51),
      'Names can be at most 50 characters.',
    );
  });

  group('date of birth', () {
    final today = CalendarDate(2026, 9, 15);

    test('is required', () {
      expect(
        AccountRules.dateOfBirthError(null, today: today),
        'Enter your date of birth.',
      );
    });

    test('must be at least 18 years ago', () {
      expect(
        AccountRules.dateOfBirthError(CalendarDate(2008, 9, 15), today: today),
        isNull,
      );
      expect(
        AccountRules.dateOfBirthError(CalendarDate(2008, 9, 16), today: today),
        'You must be at least 18 to use Kinvo.',
      );
    });

    test('cannot be in the future', () {
      expect(
        AccountRules.dateOfBirthError(CalendarDate(2026, 9, 16), today: today),
        'Date of birth cannot be in the future.',
      );
    });
  });
}
