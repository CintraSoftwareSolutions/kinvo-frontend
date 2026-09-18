import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/features/notifications/domain/app_notification.dart';
import 'package:kinvo/src/features/notifications/domain/notification_target.dart';
import 'package:kinvo/src/features/plans/domain/plan.dart';
import 'package:kinvo/src/features/plans/domain/venue.dart';
import 'package:kinvo/src/features/plans/presentation/plan_presentation.dart';

final _now = DateTime.utc(2026, 9, 18, 12);

Map<String, Object?> _planJson({
  String status = 'proposed',
  bool isMine = false,
  bool awaiting = true,
  Object? scheduledAt = '2026-09-19T18:00:00.000Z',
  Object? venue,
  Object? customLocation = 'The ramen bar',
}) {
  return {
    'id': 'p1',
    'match_id': 'm1',
    'mode': 'dating',
    'user': {
      'id': 'u2',
      'display_name': 'Sam',
      'age': 29,
      'primary_photo_url': null,
      'is_verified': false,
      'is_premium': false,
      'is_online': false,
      'last_active_at': '2026-09-18T10:00:00.000Z',
    },
    'status': status,
    'scheduled_at': scheduledAt,
    'duration_minutes': 90,
    'notes': 'By the window',
    'venue': venue,
    'custom_location': customLocation,
    'custom_address': null,
    'is_mine': isMine,
    'awaiting_my_response': awaiting,
    'shared_with_contacts': 0,
    'created_at': '2026-09-18T09:00:00.000Z',
  };
}

void main() {
  group('a plan', () {
    test('is read from the API', () {
      final plan = Plan.fromJson(_planJson());

      expect(plan.user.displayName, 'Sam');
      expect(plan.status, PlanStatus.proposed);
      expect(plan.scheduledAt, DateTime.utc(2026, 9, 19, 18));
      expect(plan.placeName, 'The ramen bar');
      expect(plan.address, isNull);
      expect(plan.awaitingMyResponse, isTrue);
    });

    test('names its venue, when it has one', () {
      final plan = Plan.fromJson(
        _planJson(
          customLocation: null,
          venue: {
            'id': 'v1',
            'name': 'Blue Bottle',
            'category': 'cafe',
            'address': '8 Kingly Street',
          },
        ),
      );

      expect(plan.placeName, 'Blue Bottle');
      expect(plan.address, '8 Kingly Street');
      expect(plan.venue?.category, VenueCategory.cafe);
    });

    test('of a status this app does not know is still read', () {
      expect(
        Plan.fromJson(_planJson(status: 'rescheduled')).status,
        PlanStatus.unknown,
      );
    });

    test('is refused when malformed', () {
      expect(
        () => Plan.fromJson(_planJson(scheduledAt: 'Friday')),
        throwsFormatException,
      );
      expect(
        () => Plan.fromJson(_planJson()..remove('user')),
        throwsFormatException,
      );
    });

    test('says what its creator and the other person can do with it', () {
      final draft = Plan.fromJson(
        _planJson(status: 'draft', isMine: true, awaiting: false),
      );
      expect(draft.canEdit, isTrue);
      expect(draft.canSend(_now), isTrue);
      expect(draft.canDelete, isTrue);
      expect(draft.canCancel(_now), isFalse);

      final sent = Plan.fromJson(_planJson(isMine: true, awaiting: false));
      expect(sent.canEdit, isTrue);
      expect(sent.canSend(_now), isFalse);
      expect(sent.canCancel(_now), isTrue);

      final theirs = Plan.fromJson(_planJson());
      expect(theirs.canEdit, isFalse);
      expect(theirs.canDelete, isFalse);

      final confirmed = Plan.fromJson(
        _planJson(status: 'confirmed', awaiting: false),
      );
      expect(confirmed.canCancel(_now), isTrue);
      // Its time has passed: nothing left to call off.
      expect(confirmed.canCancel(DateTime.utc(2026, 9, 20)), isFalse);
    });

    test('shows where it stands', () {
      String label(Map<String, Object?> json, [DateTime? now]) {
        return planBadge(Plan.fromJson(json), now ?? _now).label;
      }

      expect(label(_planJson()), 'Your answer');
      expect(label(_planJson(isMine: true, awaiting: false)), 'Waiting');
      expect(
        label(_planJson(awaiting: false), DateTime.utc(2026, 9, 20)),
        'Time passed',
      );
      expect(
        label(_planJson(status: 'confirmed', awaiting: false)),
        'Confirmed',
      );
      expect(
        label(_planJson(status: 'draft', isMine: true, awaiting: false)),
        'Draft',
      );
      expect(
        label(_planJson(status: 'cancelled', awaiting: false)),
        'Cancelled',
      );
    });
  });

  test('a venue is read from the API', () {
    final venue = Venue.fromJson(const {
      'id': 'v1',
      'name': 'Regent’s Park',
      'category': 'park',
      'description': null,
      'address': 'Chester Road',
      'city': 'London',
      'rating': 4.9,
      'price_level': null,
      'photo_url': null,
      'website_url': null,
      'modes': ['dating'],
      'distance_metres': 3400.5,
      'is_saved': true,
    });

    expect(venue.category, VenueCategory.park);
    expect(venue.rating, 4.9);
    expect(venue.distanceMetres, 3400.5);
    expect(venue.isSaved, isTrue);
  });

  test('lengths read naturally', () {
    expect(durationLabel(30), '30 min');
    expect(durationLabel(60), '1 hour');
    expect(durationLabel(90), '1 hour 30 min');
    expect(durationLabel(180), '3 hours');
  });

  test('a plan notification opens its plan', () {
    expect(
      NotificationTarget.of(NotificationCategory.planUpdate, {
        'plan_id': 'p1',
        'match_id': 'm1',
      }),
      const OpenPlan('p1'),
    );
    expect(
      NotificationTarget.of(NotificationCategory.planUpdate, const {}),
      const OpenPlans(),
    );
  });
}
