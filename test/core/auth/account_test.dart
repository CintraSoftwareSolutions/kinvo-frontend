import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/auth/account.dart';

void main() {
  test('reads the fields the app uses from GET /auth/me', () {
    final account = Account.fromJson({
      'id': '6f1c2b1e-0d7a-4c55-9d1f-2a8b3c4d5e6f',
      'display_name': 'Sarah',
      'date_of_birth': '1998-04-12',
      'age': 28,
      'status': 'active',
      'role': 'user',
      'is_verified': false,
      'is_onboarded': true,
      'subscription_tier': 'free',
      'identities': <Object?>[],
      'created_at': '2026-08-14T09:00:00.000Z',
    });

    expect(
      account,
      const Account(
        id: '6f1c2b1e-0d7a-4c55-9d1f-2a8b3c4d5e6f',
        displayName: 'Sarah',
        isOnboarded: true,
      ),
    );
  });

  test('rejects a body without the onboarding flag', () {
    expect(
      () => Account.fromJson({'id': 'u1', 'display_name': 'Sarah'}),
      throwsFormatException,
    );
  });
}
