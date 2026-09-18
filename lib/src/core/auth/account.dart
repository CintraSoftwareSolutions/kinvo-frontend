import 'package:flutter/foundation.dart';

import '../network/api_envelope.dart';

/// The signed-in user's account, from `GET /auth/me`.
@immutable
final class Account {
  const Account({
    required this.id,
    required this.displayName,
    required this.isOnboarded,
  });

  factory Account.fromJson(JsonMap json) {
    if (json case {
      'id': final String id,
      'display_name': final String displayName,
      'is_onboarded': final bool isOnboarded,
    }) {
      return Account(
        id: id,
        displayName: displayName,
        isOnboarded: isOnboarded,
      );
    }
    throw const FormatException(
      'Expected an account with id, display_name and is_onboarded.',
    );
  }

  final String id;

  final String displayName;

  /// Whether profile setup is finished. Until it is, the backend refuses
  /// discovery, matching and chat.
  final bool isOnboarded;

  @override
  bool operator ==(Object other) {
    return other is Account &&
        other.id == id &&
        other.displayName == displayName &&
        other.isOnboarded == isOnboarded;
  }

  @override
  int get hashCode => Object.hash(id, displayName, isOnboarded);
}
