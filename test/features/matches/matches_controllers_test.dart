import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/entitlements/paywall.dart';
import 'package:kinvo/src/features/chat/data/live_updates.dart';
import 'package:kinvo/src/features/chat/domain/live_update.dart';
import 'package:kinvo/src/features/discovery/domain/swipe.dart';
import 'package:kinvo/src/features/matches/data/matches_repository.dart';
import 'package:kinvo/src/features/matches/domain/match_summary.dart';
import 'package:kinvo/src/features/matches/presentation/controllers/matches_controllers.dart';

import '../../helpers/auth_fixtures.dart';
import '../../helpers/fake_kinvo_server.dart';
import '../../helpers/test_backend.dart';

const _sam = FakePerson(id: 'p1', name: 'Sam');
const _alex = FakePerson(id: 'p2', name: 'Alex');

void main() {
  late FakeKinvoServer server;
  late TestBackend backend;
  late ProviderContainer container;

  setUp(() {
    server = FakeKinvoServer()
      ..completeProfile()
      ..isOnboarded = true;
    backend = TestBackend(respond: server.respond);
    container = backend.createContainer();
  });

  FakeMatch matchWith(
    FakePerson person, {
    Duration expiresIn = const Duration(days: 10),
  }) {
    return FakeMatch(
      id: 'match-${person.id}',
      mode: 'dating',
      person: person,
      isSuperLike: false,
      matchedAt: server.now().subtract(const Duration(days: 1)),
      expiresAt: server.now().add(expiresIn),
    );
  }

  Future<MatchesListController> openMatches() async {
    container.listen(matchesListProvider(false), (_, _) {});
    await container.read(matchesListProvider(false).future);
    return container.read(matchesListProvider(false).notifier);
  }

  List<String> listed() {
    return [
      for (final match
          in container.read(matchesListProvider(false)).requireValue.items)
        match.user.displayName,
    ];
  }

  group('matches', () {
    test('are listed newest first', () async {
      server.matches.addAll([matchWith(_sam), matchWith(_alex)]);

      await openMatches();

      expect(listed(), ['Sam', 'Alex']);
    });

    test('unmatching removes the match for good', () async {
      server.matches.addAll([matchWith(_sam), matchWith(_alex)]);
      final matches = await openMatches();

      expect(await matches.unmatch('match-p1'), isNull);

      expect(listed(), ['Alex']);
      expect(server.matches.map((match) => match.id), ['match-p2']);
    });

    test('unmatching one that is already gone still clears it', () async {
      server.matches.add(matchWith(_sam));
      final matches = await openMatches();
      server.matches.clear();

      expect(await matches.unmatch('match-p1'), isNull);
      expect(listed(), isEmpty);
    });

    test('extending is a paid feature', () async {
      server.matches.add(matchWith(_sam, expiresIn: const Duration(days: 1)));
      final matches = await openMatches();

      final outcome = await matches.extend('match-p1');

      expect(outcome, isA<ExtendNeedsUpgrade>());
      expect((outcome as ExtendNeedsUpgrade).paywall, isA<PremiumFeature>());
    });

    test('extending adds a week to the match', () async {
      server
        ..isPremium = true
        ..matches.add(matchWith(_sam, expiresIn: const Duration(days: 1)));
      final matches = await openMatches();

      final outcome = await matches.extend('match-p1');

      expect(outcome, isA<Extended>());
      final extended = container
          .read(matchesListProvider(false))
          .requireValue
          .items
          .single;
      expect(extended.expiresAt, server.now().add(const Duration(days: 8)));
      expect(extended.extensionCount, 1);
    });
  });

  group('matches, live', () {
    LiveUpdates updates() => container.read(liveUpdatesProvider);

    MatchSummary listedMatch() {
      return container
          .read(matchesListProvider(false))
          .requireValue
          .items
          .single;
    }

    test('show the latest message and unread count', () async {
      server.matches.add(matchWith(_sam));
      await openMatches();

      updates().publish(
        ConversationActivity(
          conversationId: 'conversation-match-p1',
          lastMessageAt: server.now(),
          lastMessagePreview: 'See you at 7',
          unreadCount: 2,
        ),
      );
      await settle();

      expect(listedMatch().lastMessagePreview, 'See you at 7');
      expect(listedMatch().unreadCount, 2);
    });

    test('show who is online', () async {
      server.matches.add(matchWith(_sam));
      await openMatches();

      updates().publish(
        PresenceChanged(
          userId: 'p1',
          isOnline: true,
          lastActiveAt: server.now(),
        ),
      );
      await settle();

      expect(listedMatch().user.isOnline, isTrue);
    });

    test('gain a new match at the top', () async {
      server.matches.add(matchWith(_sam));
      await openMatches();
      final alex = matchWith(_alex);
      server.matches.insert(0, alex);

      final created = await container
          .read(matchesRepositoryProvider)
          .fetchMatch(alex.id);
      updates().publish(MatchCreated(created));
      await settle();

      expect(listed(), ['Alex', 'Sam']);
    });

    test('lose a match ended elsewhere', () async {
      server.matches.addAll([matchWith(_sam), matchWith(_alex)]);
      await openMatches();

      updates().publish(const MatchEnded('match-p1'));
      await settle();

      expect(listed(), ['Alex']);
    });

    test('move a conversation archived elsewhere', () async {
      server.matches.add(matchWith(_sam));
      await openMatches();
      container.listen(matchesListProvider(true), (_, _) {});
      await container.read(matchesListProvider(true).future);

      server.matches.single.isArchived = true;
      updates().publish(
        const ConversationActivity(
          conversationId: 'conversation-match-p1',
          isArchived: true,
        ),
      );
      await settle();

      expect(listed(), isEmpty);
      final archived = await container.read(matchesListProvider(true).future);
      expect(archived.items.single.id, 'match-p1');
    });
  });

  group('the likes inbox', () {
    Future<LikesInbox> openInbox() async {
      container.listen(likesInboxProvider('dating'), (_, _) {});
      return container.read(likesInboxProvider('dating').future);
    }

    test(
      'is locked without a paid plan, but says how many are waiting',
      () async {
        server.likesYou['dating'] = [_sam, _alex];

        final inbox = await openInbox();

        expect(inbox, isA<LikesLocked>());
        // The count comes from the stats, which say how many without who.
        expect((inbox as LikesLocked).waiting, 2);
        expect(backend.requestsTo('/discovery/dating/stats'), hasLength(1));
      },
    );

    test('lists who liked the user on a paid plan', () async {
      server
        ..isPremium = true
        ..likesYou['dating'] = [_sam, _alex];

      final inbox = await openInbox();

      expect(inbox, isA<LikesVisible>());
      expect(
        (inbox as LikesVisible).likes.items.map(
          (like) => like.user.displayName,
        ),
        ['Sam', 'Alex'],
      );
    });

    test(
      'liking someone back makes a match and takes them off the list',
      () async {
        server
          ..isPremium = true
          ..likesYou['dating'] = [_sam, _alex]
          ..likesBack.add('p1');
        final inbox = await openInbox() as LikesVisible;

        final outcome = await container
            .read(likesInboxProvider('dating').notifier)
            .answer(inbox.likes.items.first, SwipeAction.like);

        expect(outcome, isA<Answered>());
        expect((outcome as Answered).result.match?.id, 'match-p1');
        final after = container.read(likesInboxProvider('dating')).requireValue;
        expect(
          (after as LikesVisible).likes.items.map((like) => like.user.id),
          ['p2'],
        );
        expect(server.matches.single.person.id, 'p1');
      },
    );

    test('someone already answered elsewhere just leaves the list', () async {
      server
        ..isPremium = true
        ..likesYou['dating'] = [_sam];
      final inbox = await openInbox() as LikesVisible;
      server.swipes['dating'] = [(userId: 'p1', action: 'pass')];

      final outcome = await container
          .read(likesInboxProvider('dating').notifier)
          .answer(inbox.likes.items.single, SwipeAction.like);

      expect(outcome, isA<AnswerGone>());
      final after = container.read(likesInboxProvider('dating')).requireValue;
      expect((after as LikesVisible).likes.items, isEmpty);
    });
  });
}
