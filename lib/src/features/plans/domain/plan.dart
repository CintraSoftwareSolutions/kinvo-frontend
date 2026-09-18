import 'package:flutter/foundation.dart';

import '../../../core/network/api_envelope.dart';
import '../../profile/domain/user_summary.dart';
import 'venue.dart';

/// Where a plan stands.
enum PlanStatus {
  /// Only its creator can see it. Sending it proposes it.
  draft('draft'),

  /// Sent, and waiting for the other person's answer.
  proposed('proposed'),
  confirmed('confirmed'),
  declined('declined'),
  cancelled('cancelled'),

  /// Its time passed. The server marks this a few hours after.
  completed('completed'),

  /// A status added to the server after this version of the app.
  unknown('');

  const PlanStatus(this.wireValue);

  /// Its name in the API.
  final String wireValue;

  static PlanStatus fromWireValue(String value) {
    for (final status in values) {
      if (status != unknown && status.wireValue == value) return status;
    }
    return unknown;
  }
}

/// A place from Kinvo's list, as a plan names it.
@immutable
final class PlanVenue {
  const PlanVenue({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
  });

  factory PlanVenue.fromJson(JsonMap json) {
    if (json case {
      'id': final String id,
      'name': final String name,
      'category': final String category,
      'address': final String? address,
    } when id.isNotEmpty) {
      return PlanVenue(
        id: id,
        name: name,
        category: VenueCategory.fromWireValue(category),
        address: address,
      );
    }
    throw const FormatException(
      'Expected a venue with id, name, category and address.',
    );
  }

  final String id;
  final String name;
  final VenueCategory category;
  final String? address;
}

/// A plan to meet a match: where, when and for how long.
@immutable
final class Plan {
  const Plan({
    required this.id,
    required this.matchId,
    required this.mode,
    required this.user,
    required this.status,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.notes,
    required this.venue,
    required this.customLocation,
    required this.customAddress,
    required this.isMine,
    required this.awaitingMyResponse,
    required this.sharedWithContacts,
    required this.createdAt,
  });

  /// Reads one plan, as every plans endpoint returns it.
  factory Plan.fromJson(JsonMap json) {
    if (json case {
      'id': final String id,
      'match_id': final String matchId,
      'mode': final String mode,
      'user': final JsonMap user,
      'status': final String status,
      'scheduled_at': final String? scheduledAt,
      'duration_minutes': final int? durationMinutes,
      'notes': final String? notes,
      'venue': final JsonMap? venue,
      'custom_location': final String? customLocation,
      'custom_address': final String? customAddress,
      'is_mine': final bool isMine,
      'awaiting_my_response': final bool awaitingMyResponse,
      'shared_with_contacts': final int sharedWithContacts,
      'created_at': final String createdAt,
    } when id.isNotEmpty) {
      final created = DateTime.tryParse(createdAt);
      final scheduled = scheduledAt == null
          ? null
          : DateTime.tryParse(scheduledAt);
      if (created != null && (scheduledAt == null || scheduled != null)) {
        return Plan(
          id: id,
          matchId: matchId,
          mode: mode,
          user: UserSummary.fromJson(user),
          status: PlanStatus.fromWireValue(status),
          scheduledAt: scheduled,
          durationMinutes: durationMinutes,
          notes: notes,
          venue: venue == null ? null : PlanVenue.fromJson(venue),
          customLocation: customLocation,
          customAddress: customAddress,
          isMine: isMine,
          awaitingMyResponse: awaitingMyResponse,
          sharedWithContacts: sharedWithContacts,
          createdAt: created,
        );
      }
    }
    throw const FormatException(
      'Expected a plan with id, match_id, mode, user, status, scheduled_at, '
      'duration_minutes, notes, venue, custom_location, custom_address, '
      'is_mine, awaiting_my_response, shared_with_contacts and created_at.',
    );
  }

  final String id;
  final String matchId;

  /// The mode of the match it belongs to.
  final String mode;

  /// The other person.
  final UserSummary user;

  final PlanStatus status;

  /// When it starts. Only a draft can be without one.
  final DateTime? scheduledAt;

  final int? durationMinutes;
  final String? notes;

  /// A place from Kinvo's list, or `null` for one typed in, [customLocation].
  final PlanVenue? venue;

  final String? customLocation;
  final String? customAddress;

  /// Whether the signed-in user suggested it.
  final bool isMine;

  /// Whether it waits on the signed-in user's answer. The server stops
  /// saying so once its time has passed.
  final bool awaitingMyResponse;

  /// How many trusted contacts it was shared with.
  final int sharedWithContacts;

  final DateTime createdAt;

  /// Where it is, in a few words.
  String get placeName => venue?.name ?? customLocation ?? 'Somewhere';

  /// The address, when there's one.
  String? get address {
    final address = venue?.address ?? customAddress;
    return address == null || address.trim().isEmpty ? null : address;
  }

  /// Whether its time has come, at [now].
  bool hasStarted(DateTime now) {
    final scheduledAt = this.scheduledAt;
    return scheduledAt != null && !scheduledAt.isAfter(now);
  }

  /// Whether its creator can still change it.
  bool get canEdit {
    return isMine &&
        (status == PlanStatus.draft || status == PlanStatus.proposed);
  }

  /// Whether it's a draft its creator can send, at [now].
  bool canSend(DateTime now) {
    return isMine &&
        status == PlanStatus.draft &&
        scheduledAt != null &&
        !hasStarted(now);
  }

  /// Whether either person can call it off, at [now]. A draft is deleted
  /// instead.
  bool canCancel(DateTime now) {
    return switch (status) {
      PlanStatus.proposed => true,
      PlanStatus.confirmed => !hasStarted(now),
      _ => false,
    };
  }

  bool get canDelete => isMine && status == PlanStatus.draft;
}
