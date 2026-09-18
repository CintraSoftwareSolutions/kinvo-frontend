import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/config/server_config.dart';
import 'package:kinvo/src/core/entitlements/paywall.dart';
import 'package:kinvo/src/core/network/api_error_code.dart';
import 'package:kinvo/src/core/network/api_exception.dart';
import 'package:kinvo/src/features/discovery/data/discovery_repository.dart';
import 'package:kinvo/src/features/discovery/domain/deck_card.dart';
import 'package:kinvo/src/features/discovery/domain/deck_stats.dart';
import 'package:kinvo/src/features/discovery/domain/discovery_formatting.dart';
import 'package:kinvo/src/features/discovery/domain/swipe.dart';
import 'package:kinvo/src/features/matches/domain/match_summary.dart';
import 'package:kinvo/src/features/modes/domain/mode_filters.dart';
import 'package:kinvo/src/features/modes/domain/user_modes.dart';
import 'package:kinvo/src/features/profile/domain/public_profile.dart';
import 'package:kinvo/src/features/profile/domain/user_summary.dart';

Map<String, Object?> _user({
  String id = 'u2',
  Object? age = 28,
  Object? photo = 'https://cdn.example.com/p.jpg',
  bool online = false,
  String lastActive = '2026-09-17T08:00:00.000Z',
}) {
  return {
    'id': id,
    'display_name': 'Sarah',
    'age': age,
    'primary_photo_url': photo,
    'is_verified': true,
    'is_premium': false,
    'is_online': online,
    'last_active_at': lastActive,
  };
}

Map<String, Object?> _quota({
  int limit = 50,
  int used = 3,
  bool unlimited = false,
}) {
  return unlimited
      ? {'limit': -1, 'used': 0, 'remaining': -1, 'is_unlimited': true}
      : {
          'limit': limit,
          'used': used,
          'remaining': limit - used,
          'is_unlimited': false,
        };
}

Map<String, Object?> _mode(
  String mode, {
  bool enabled = true,
  bool primary = false,
}) {
  return {
    'mode': mode,
    'label': mode,
    'is_enabled': enabled,
    'is_primary': primary,
    'requires_verification': false,
    'can_enable': true,
    'min_age': 21,
    'max_age': 40,
    'radius_metres': 16093,
    'verified_only': true,
  };
}

ServerConfig _config() {
  return ServerConfig.fromJson({
    'modes': [
      for (final (value, label, like, superLike) in const [
        ('dating', 'Dating', 'Like', 'Super Like'),
        ('networking', 'Networking', 'Connect', 'Intro'),
        ('fitness', 'Fitness', 'Fitness', 'Train'),
      ])
        {
          'value': value,
          'label': label,
          'primary_action_label': like,
          'super_action_label': superLike,
          'description': '',
        },
    ],
    'interests': <Object?>[],
    'limits': {'max_interests': 10, 'max_photos': 6, 'bio_max_length': 500},
  });
}

ApiErrorException _apiError(
  ApiErrorCode code, {
  Map<String, Object?>? details,
  String message = 'Nope.',
}) {
  return ApiErrorException(
    code: code,
    message: message,
    statusCode: 400,
    details: details,
  );
}

void main() {
  group('a user summary', () {
    test('is read from the compact shape every list shares', () {
      final user = UserSummary.fromJson(_user());

      expect(user.id, 'u2');
      expect(user.displayName, 'Sarah');
      expect(user.age, 28);
      expect(user.photoUrl, Uri.parse('https://cdn.example.com/p.jpg'));
      expect(user.isVerified, isTrue);
      expect(user.lastActiveAt, DateTime.utc(2026, 9, 17, 8));
    });

    test('may have no photo and no age yet', () {
      final user = UserSummary.fromJson(_user(age: null, photo: null));

      expect(user.age, isNull);
      expect(user.photoUrl, isNull);
    });

    test('is refused without the fields a card relies on', () {
      expect(
        () => UserSummary.fromJson({..._user()}..remove('is_verified')),
        throwsFormatException,
      );
      expect(
        () => UserSummary.fromJson(_user(lastActive: 'yesterday')),
        throwsFormatException,
      );
    });
  });

  group('a deck card', () {
    test('is read from GET /discovery/{mode}/deck', () {
      final card = DeckCard.fromJson({
        'entry_id': 'e1',
        'position': 3,
        'distance_metres': 3218,
        'user': _user(),
        'bio': 'Hello',
        'interests': ['coffee', 'hiking'],
      });

      expect(card.entryId, 'e1');
      expect(card.position, 3);
      expect(card.distanceMetres, 3218.0);
      expect(card.interestSlugs, ['coffee', 'hiking']);
    });

    test('may not know the distance', () {
      final card = DeckCard.fromJson({
        'entry_id': 'e1',
        'position': 0,
        'distance_metres': null,
        'user': _user(),
        'bio': null,
        'interests': <Object?>[],
      });

      expect(card.distanceMetres, isNull);
      expect(card.bio, isNull);
    });
  });

  group('a swipe result', () {
    test('carries the match a second like makes', () {
      final result = SwipeResult.fromJson({
        'action': 'super_like',
        'is_match': true,
        'match': {
          'id': 'm1',
          'mode': 'dating',
          'is_super_like': true,
          'matched_at': '2026-09-17T10:00:00.000Z',
        },
        'quota': _quota(),
      });

      expect(result.action, SwipeAction.superLike);
      expect(result.match?.id, 'm1');
      expect(result.allowance.remaining, 47);
      expect(result.allowance.isUnlimited, isFalse);
    });

    test('reads the server\'s -1 as no limit', () {
      final result = SwipeResult.fromJson({
        'action': 'pass',
        'is_match': false,
        'match': null,
        'quota': _quota(unlimited: true),
      });

      expect(result.match, isNull);
      expect(result.allowance.isUnlimited, isTrue);
      expect(result.allowance.remaining, isNull);
    });

    test('is refused when is_match and the match disagree', () {
      expect(
        () => SwipeResult.fromJson({
          'action': 'like',
          'is_match': true,
          'match': null,
          'quota': _quota(),
        }),
        throwsFormatException,
      );
    });
  });

  test('deck stats are read with and without a boost', () {
    final quiet = DeckStats.fromJson({
      'mode': 'dating',
      'liked': 4,
      'passed': 9,
      'super_liked': 1,
      'matches': 2,
      'likes_received': 3,
      'cards_remaining': 0,
      'boost': null,
      'swipe_quota': _quota(),
    });
    expect(quiet.likesReceived, 3);
    expect(quiet.boost, isNull);

    final boosted = DeckStats.fromJson({
      'mode': 'dating',
      'liked': 0,
      'passed': 0,
      'super_liked': 0,
      'matches': 0,
      'likes_received': 0,
      'cards_remaining': 12,
      'boost': {
        'id': 'b1',
        'mode': 'dating',
        'started_at': '2026-09-17T10:00:00.000Z',
        'ends_at': '2026-09-17T10:30:00.000Z',
        'is_active': true,
      },
      'swipe_quota': _quota(unlimited: true),
    });
    expect(
      boosted.boost?.isActiveAt(DateTime.utc(2026, 9, 17, 10, 10)),
      isTrue,
    );
    expect(boosted.boost?.isActiveAt(DateTime.utc(2026, 9, 17, 11)), isFalse);
  });

  group('mode filters', () {
    test('are read from a mode and sent back as the same fields', () {
      final mode = UserMode.tryFromJson(_mode('dating'))!;

      expect(
        mode.filters,
        const ModeFilters(
          minAge: 21,
          maxAge: 40,
          radiusMetres: 16093,
          verifiedOnly: true,
        ),
      );
      expect(mode.filters.toJson(), {
        'min_age': 21,
        'max_age': 40,
        'radius_metres': 16093,
        'verified_only': true,
      });
    });

    test('an age range the wrong way round is not a mode', () {
      expect(UserMode.tryFromJson({..._mode('dating'), 'min_age': 50}), isNull);
    });
  });

  group('Discover\'s modes', () {
    test('are the switched-on ones, main mode first, in catalogue order', () {
      final modes = discoveryModesFrom(
        UserModes.fromJson({
          'modes': [
            _mode('fitness'),
            _mode('networking', primary: true),
            _mode('dating'),
            _mode('study_buddy', enabled: false),
          ],
          'max_simultaneous_modes': 3,
        }),
        _config(),
      );

      expect(modes.map((mode) => mode.value), [
        'networking',
        'dating',
        'fitness',
      ]);
      expect(modes.first.likeLabel, 'Connect');
      expect(modes.first.superLikeLabel, 'Intro');
      expect(modes.first.isPrimary, isTrue);
      expect(modes.first.filters.verifiedOnly, isTrue);
    });

    test('still offer a mode the catalogue doesn\'t know', () {
      final modes = discoveryModesFrom(
        UserModes.fromJson({
          'modes': [_mode('board_games', primary: true)],
          'max_simultaneous_modes': 3,
        }),
        _config(),
      );

      expect(modes.single.label, 'Board games');
      expect(modes.single.likeLabel, 'Like');
      expect(modes.single.superLikeLabel, 'Super Like');
    });
  });

  group('a paywall', () {
    test('is read from a used-up daily allowance', () {
      final paywall = Paywall.fromError(
        _apiError(
          ApiErrorCode.quotaExceeded,
          message: 'You have used all 50 swipes for today.',
          details: {
            'quota': 'swipes',
            'resets_at': '2026-09-18T00:00:00.000Z',
            'upgrade_available': true,
          },
        ),
      );

      expect(paywall, isA<DailyLimitReached>());
      expect(paywall!.message, 'You have used all 50 swipes for today.');
      expect(paywall.canUpgrade, isTrue);
      expect(
        (paywall as DailyLimitReached).resetsAt,
        DateTime.utc(2026, 9, 18),
      );
    });

    test('is read from a paid feature', () {
      final paywall = Paywall.fromError(
        _apiError(
          ApiErrorCode.premiumRequired,
          details: {'required_feature': 'rewind', 'upgrade_available': false},
        ),
      );

      expect(paywall, isA<PremiumFeature>());
      expect((paywall! as PremiumFeature).feature, 'rewind');
      // On the top plan there's nothing to upgrade to.
      expect(paywall.canUpgrade, isFalse);
    });

    test('is not read from any other failure', () {
      expect(Paywall.fromError(_apiError(ApiErrorCode.conflict)), isNull);
      expect(
        Paywall.fromError(const NetworkException(NetworkFailure.offline)),
        isNull,
      );
    });
  });

  test('a public profile keeps answered questions, in the order chosen', () {
    final profile = PublicProfile.fromJson({
      'user': _user(),
      'bio': 'Hi',
      'job_title': 'Designer',
      'organisation': 'Studio',
      'education': 'postgraduate',
      'height_cm': 170,
      'city': 'Leeds',
      'distance_metres': 1200.5,
      'drinking': 'socially',
      'smoking': null,
      'exercise': 'often',
      'diet': null,
      'pets': null,
      'children': null,
      'interests': [
        {'id': 'i1', 'slug': 'coffee', 'label': 'Coffee', 'category': 'food'},
        {'slug': 'broken'},
      ],
      'prompts': [
        {'question': 'Second?', 'answer': 'B', 'position': 1},
        {'question': 'First?', 'answer': 'A', 'position': 0},
        {'question': 'Unanswered', 'answer': '', 'position': 2},
      ],
    });

    expect(profile.lifestyle, {'drinking': 'socially', 'exercise': 'often'});
    expect(profile.interests.map((i) => i.label), ['Coffee']);
    expect(profile.prompts.map((p) => p.question), ['First?', 'Second?']);
    expect(profile.distanceMetres, 1200.5);
  });

  test('a match and a like are read from their lists', () {
    final match = MatchSummary.fromJson({
      'id': 'm1',
      'mode': 'dating',
      'status': 'active',
      'is_super_like': false,
      'matched_at': '2026-09-15T10:00:00.000Z',
      'expires_at': '2026-09-29T10:00:00.000Z',
      'is_expired': false,
      'extension_count': 1,
      'is_writable': true,
      'user': _user(),
      'conversation_id': 'c1',
      'last_message_at': null,
      'last_message_preview': null,
      'unread_count': 2,
    });
    expect(match.expiresAt, DateTime.utc(2026, 9, 29, 10));
    expect(match.unreadCount, 2);
    expect(match.lastMessageAt, isNull);

    final like = LikeReceived.fromJson({
      'swipe_id': 's1',
      'is_super_like': true,
      'liked_at': '2026-09-17T07:00:00.000Z',
      'user': _user(),
    });
    expect(like.isSuperLike, isTrue);
    expect(like.user.displayName, 'Sarah');
  });

  group('formatting', () {
    test('activity is told in days, never minutes', () {
      final now = DateTime.utc(2026, 9, 17, 12);
      UserSummary active(Duration ago, {bool online = false}) {
        return UserSummary.fromJson(
          _user(
            online: online,
            lastActive: now.subtract(ago).toIso8601String(),
          ),
        );
      }

      expect(
        activityLabel(active(Duration.zero, online: true), now: now),
        'Online now',
      );
      expect(
        activityLabel(active(const Duration(minutes: 12)), now: now),
        'Active today',
      );
      expect(
        activityLabel(active(const Duration(days: 3)), now: now),
        'Active this week',
      );
      expect(activityLabel(active(const Duration(days: 30)), now: now), isNull);
    });

    test('someone who hides when they were active shows no activity', () {
      final hidden = UserSummary.fromJson({..._user(), 'last_active_at': null});

      expect(hidden.lastActiveAt, isNull);
      expect(activityLabel(hidden, now: DateTime.utc(2026, 9, 17)), isNull);
      expect(
        () => UserSummary.fromJson({..._user(), 'last_active_at': 'lately'}),
        throwsFormatException,
      );
    });

    test('API values read as words', () {
      expect(humanise('have_children'), 'Have children');
      expect(humanise('study_buddy'), 'Study buddy');
    });
  });
}
