import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/entitlements/paywall.dart';
import 'package:kinvo/src/features/discovery/domain/swipe.dart';
import 'package:kinvo/src/features/discovery/presentation/controllers/deck_controller.dart';
import 'package:kinvo/src/features/discovery/presentation/controllers/discovery_actions.dart';
import 'package:kinvo/src/features/discovery/presentation/controllers/discovery_modes_controller.dart';
import 'package:kinvo/src/features/matches/data/matches_repository.dart';

import '../../../helpers/fake_kinvo_server.dart';
import '../../../helpers/test_backend.dart';

const _people = [
  FakePerson(id: 'p1', name: 'Ada', isVerified: true),
  FakePerson(id: 'p2', name: 'Bea', age: 45),
  // Inside the default 30 miles, outside 10.
  FakePerson(id: 'p3', name: 'Cat', distanceMetres: 30000),
];

void main() {
  late FakeKinvoServer server;
  late TestBackend backend;
  late ProviderContainer container;

  setUp(() {
    server = FakeKinvoServer()
      ..completeProfile()
      ..isOnboarded = true
      ..decks['dating'] = [..._people];
    backend = TestBackend(respond: server.respond);
    container = backend.createContainer();
  });

  /// Today's deck for dating, kept alive for the test.
  Future<DeckController> openDeck() async {
    container.listen(deckControllerProvider('dating'), (_, _) {});
    await container.read(deckControllerProvider('dating').future);
    return container.read(deckControllerProvider('dating').notifier);
  }

  List<String> names() {
    return [
      for (final card
          in container
              .read(deckControllerProvider('dating'))
              .requireValue
              .cards)
        card.user.displayName,
    ];
  }

  group('the deck', () {
    test('shows today\'s cards in order', () async {
      await openDeck();

      expect(names(), ['Ada', 'Bea', 'Cat']);
      expect(
        backend.requestsTo('/discovery/dating/deck').single.uri.queryParameters,
        {'limit': '25'},
      );
    });

    test('a pass moves on without using any likes', () async {
      final deck = await openDeck();

      final outcome = await deck.swipe(SwipeAction.pass);

      expect(outcome, isA<Swiped>());
      expect(names(), ['Bea', 'Cat']);
      expect(backend.requestsTo('/discovery/dating/swipe').single.data, {
        'target_id': 'p1',
        'action': 'pass',
      });
      expect(server.likesUsed, 0);
    });

    test('a like that is returned makes a match', () async {
      server
        ..likesBack.add('p1')
        ..dailyLikes = 50;
      final deck = await openDeck();

      final outcome = await deck.swipe(SwipeAction.like);

      expect(outcome, isA<Swiped>());
      final swiped = outcome! as Swiped;
      expect(swiped.card.user.displayName, 'Ada');
      expect(swiped.result.match?.id, 'match-p1');
      // What's left of today's likes, straight from the swipe.
      expect(
        container
            .read(deckControllerProvider('dating'))
            .requireValue
            .allowance
            ?.remaining,
        49,
      );
    });

    test('a used-up allowance keeps the card and offers an upgrade', () async {
      server
        ..dailyLikes = 1
        ..likesUsed = 1;
      final deck = await openDeck();

      final outcome = await deck.swipe(SwipeAction.like);

      expect(outcome, isA<SwipeNeedsUpgrade>());
      final paywall = (outcome! as SwipeNeedsUpgrade).paywall;
      expect(paywall, isA<DailyLimitReached>());
      expect(
        (paywall as DailyLimitReached).resetsAt,
        DateTime.utc(2026, 9, 18),
      );
      expect(names(), ['Ada', 'Bea', 'Cat']);
    });

    test('a card already answered elsewhere just goes', () async {
      final deck = await openDeck();
      server.swipes['dating'] = [(userId: 'p1', action: 'like')];

      final outcome = await deck.swipe(SwipeAction.like);

      expect(outcome, isA<CardGone>());
      expect(names(), ['Bea', 'Cat']);
    });

    test('a swipe that never arrives brings the card back', () async {
      final deck = await openDeck();
      server.intercept = (options) async {
        if (options.path.endsWith('/swipe')) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: const SocketException('Network is unreachable'),
          );
        }
        return null;
      };

      final outcome = await deck.swipe(SwipeAction.like);

      expect(outcome, isA<SwipeFailed>());
      expect(
        (outcome! as SwipeFailed).message,
        contains('internet connection'),
      );
      expect(names(), ['Ada', 'Bea', 'Cat']);
    });

    test('swipes go one at a time', () async {
      final deck = await openDeck();
      final reply = Completer<void>();
      server.intercept = (options) async {
        if (options.path.endsWith('/swipe')) await reply.future;
        return null;
      };

      final first = deck.swipe(SwipeAction.pass);
      // The next card is on show straight away, but can't be swiped yet.
      expect(names(), ['Bea', 'Cat']);
      expect(await deck.swipe(SwipeAction.pass), isNull);

      reply.complete();
      expect(await first, isA<Swiped>());
      expect(backend.requestsTo('/discovery/dating/swipe'), hasLength(1));
    });

    test('fetches the next page before the cards run out', () async {
      server.decks['dating'] = [
        for (var i = 0; i < 30; i++) FakePerson(id: 'p$i', name: 'Person $i'),
      ];
      final deck = await openDeck();
      expect(names(), hasLength(25));

      for (var i = 0; i < 21; i++) {
        await deck.swipe(SwipeAction.pass);
      }

      final state = container
          .read(deckControllerProvider('dating'))
          .requireValue;
      expect(state.cards, hasLength(9));
      expect(state.hasMore, isFalse);
      expect(backend.requestsTo('/discovery/dating/deck'), hasLength(2));
    });

    test('runs out once every card is answered', () async {
      server.decks['dating'] = [_people.first];
      final deck = await openDeck();

      await deck.swipe(SwipeAction.pass);

      expect(
        container
            .read(deckControllerProvider('dating'))
            .requireValue
            .isExhausted,
        isTrue,
      );
    });
  });

  group('rewind', () {
    test('is a paid feature', () async {
      final deck = await openDeck();
      await deck.swipe(SwipeAction.pass);

      final outcome = await deck.rewind();

      expect(outcome, isA<RewindNeedsUpgrade>());
      expect(names(), ['Bea', 'Cat']);
    });

    test('brings the last card back to the top', () async {
      server.isPremium = true;
      final deck = await openDeck();
      await deck.swipe(SwipeAction.pass);

      final outcome = await deck.rewind();

      expect(outcome, isA<Rewound>());
      expect((outcome! as Rewound).result.restoredUserId, 'p1');
      expect(names(), ['Ada', 'Bea', 'Cat']);
    });

    test('says when there is nothing to bring back', () async {
      server.isPremium = true;
      final deck = await openDeck();

      final outcome = await deck.rewind();

      expect(outcome, isA<RewindFailed>());
      expect(
        (outcome! as RewindFailed).message,
        'There is nothing to rewind in this mode.',
      );
    });

    test('never undoes a swipe that became a match', () async {
      server
        ..isPremium = true
        ..likesBack.add('p1');
      final deck = await openDeck();
      await deck.swipe(SwipeAction.like);

      final outcome = await deck.rewind();

      // The match to offer Unmatch on; nothing else changed.
      expect(outcome, isA<RewindKeptMatch>());
      expect((outcome! as RewindKeptMatch).matchId, 'match-p1');
      expect(names(), ['Bea', 'Cat']);
      expect(server.matches.single.person.id, 'p1');
      expect(server.swipes['dating'], hasLength(1));
    });

    test('has no match to offer once it has ended', () async {
      server
        ..isPremium = true
        ..likesBack.add('p1');
      final deck = await openDeck();
      await deck.swipe(SwipeAction.like);
      await container.read(matchesRepositoryProvider).unmatch('match-p1');

      final outcome = await deck.rewind();

      expect(outcome, isA<RewindKeptMatch>());
      final kept = outcome! as RewindKeptMatch;
      expect(kept.matchId, isNull);
      expect(
        kept.message,
        'You matched with this person, so that swipe cannot be undone.',
      );
      expect(names(), ['Bea', 'Cat']);
    });

    test('sends one rewind for two quick taps', () async {
      server.isPremium = true;
      final deck = await openDeck();
      await deck.swipe(SwipeAction.pass);

      final first = deck.rewind();
      final second = await deck.rewind();

      expect(second, isNull);
      expect(await first, isA<Rewound>());
      expect(backend.requestsTo('/discovery/dating/rewind'), hasLength(1));
      expect(names(), ['Ada', 'Bea', 'Cat']);
    });
  });

  group('filters', () {
    test('saved filters rebuild the deck from them', () async {
      await openDeck();
      final modes = await container.read(discoveryModesProvider.future);
      final dating = modes.single;
      final form = filtersFormProvider((dating.value, dating.filters));
      container.listen(form, (_, _) {});

      container.read(form.notifier)
        ..setAgeRange(18, 40)
        ..setRadiusMetres(16093)
        ..setVerifiedOnly(true);
      expect(await container.read(form.notifier).save(), isTrue);

      expect(backend.requestsTo('/modes/dating').single.data, {
        'min_age': 18,
        'max_age': 40,
        'radius_metres': 16093,
        'verified_only': true,
      });
      await container.read(deckControllerProvider('dating').future);
      expect(names(), ['Ada']);
    });

    test('nothing is sent when nothing changed', () async {
      final modes = await container.read(discoveryModesProvider.future);
      final dating = modes.single;
      final form = filtersFormProvider((dating.value, dating.filters));
      container.listen(form, (_, _) {});

      expect(await container.read(form.notifier).save(), isTrue);
      expect(backend.requestsTo('/modes/dating'), isEmpty);
    });
  });

  group('boost', () {
    test('is a paid feature', () async {
      container.listen(boostControllerProvider('dating'), (_, _) {});

      final outcome = await container
          .read(boostControllerProvider('dating').notifier)
          .start();

      expect(outcome, isA<BoostNeedsUpgrade>());
    });

    test('starts, and shows up in the stats', () async {
      server.isPremium = true;
      container
        ..listen(boostControllerProvider('dating'), (_, _) {})
        ..listen(deckStatsProvider('dating'), (_, _) {});

      final outcome = await container
          .read(boostControllerProvider('dating').notifier)
          .start();

      expect(outcome, isA<BoostStarted>());
      final stats = await container.read(deckStatsProvider('dating').future);
      expect(stats.boost?.endsAt, DateTime.utc(2026, 9, 17, 10, 30));
    });
  });
}
