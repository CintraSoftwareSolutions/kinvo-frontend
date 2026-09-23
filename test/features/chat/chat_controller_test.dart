import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/auth/account_providers.dart';
import 'package:kinvo/src/core/auth/auth_providers.dart';
import 'package:kinvo/src/core/entitlements/paywall.dart';
import 'package:kinvo/src/core/media/photo_processing.dart';
import 'package:kinvo/src/core/realtime/realtime_events.dart';
import 'package:kinvo/src/core/realtime/realtime_providers.dart';
import 'package:kinvo/src/features/chat/presentation/controllers/chat_controller.dart';
import 'package:kinvo/src/features/matches/presentation/controllers/matches_controllers.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/auth_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_kinvo_server.dart';
import '../../helpers/test_backend.dart';

const _sam = FakePerson(id: 'p1', name: 'Sam');

void main() {
  // Chat only marks messages read while the app is on screen, which it asks
  // the Flutter binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeKinvoServer server;
  late TestBackend backend;
  late ProviderContainer container;
  late FakeMatch match;

  setUp(() async {
    server = FakeKinvoServer()
      ..completeProfile()
      ..isOnboarded = true;
    match = FakeMatch(
      id: 'match-p1',
      mode: 'dating',
      person: _sam,
      isSuperLike: false,
      matchedAt: server.now().subtract(const Duration(days: 1)),
      expiresAt: server.now().add(const Duration(days: 10)),
    );
    server.matches.add(match);
    backend = TestBackend(respond: server.respond, realtime: server.realtime);
    await backend.tokenStore.write(liveSession());
    container = backend.createContainer();
  });

  AsyncNotifierProvider<ChatController, ChatThread> provider() {
    return chatControllerProvider(match.conversationId);
  }

  Future<ChatController> openChat() async {
    await container.read(sessionManagerProvider).ready;
    await container.read(currentAccountProvider.future);
    container.listen(provider(), (_, _) {});
    await container.read(provider().future);
    return container.read(provider().notifier);
  }

  ChatThread thread() => container.read(provider()).requireValue;

  /// Opens the live connection and waits for it.
  Future<void> goLive() async {
    container.read(realtimeConnectionProvider).setWanted(true);
    await settle();
  }

  /// Waits for new messages to be marked read.
  Future<void> waitForRead() async {
    await Future<void>.delayed(
      ChatController.readDelay + const Duration(milliseconds: 100),
    );
    await settle();
  }

  group('opening', () {
    test('shows the newest messages, and reads further back', () async {
      for (var i = 1; i <= 35; i++) {
        server.addHistory(match, 'message $i', fromUser: i.isEven);
      }

      final chat = await openChat();

      expect(thread().messages, hasLength(30));
      expect(thread().messages.first.body, 'message 35');
      expect(thread().hasOlder, isTrue);

      await chat.loadOlder();

      expect(thread().messages, hasLength(35));
      expect(thread().messages.last.body, 'message 1');
      expect(thread().hasOlder, isFalse);
    });

    test('tells the user apart from the other person', () async {
      server
        ..addHistory(match, 'From Sam', fromUser: false)
        ..addHistory(match, 'From me', fromUser: true);

      await openChat();

      final [mine, theirs] = thread().messages;
      expect(thread().isMine(mine), isTrue);
      expect(thread().isMine(theirs), isFalse);
    });

    test('marks unread messages read', () async {
      server.addHistory(match, 'Hi!', fromUser: false, read: false);

      await openChat();
      await waitForRead();

      expect(match.readByUser, 1);
      expect(match.unreadCount, 0);
      expect(thread().conversation.unreadCount, 0);
      expect(thread().hasUnread, isFalse);
    });

    test('leaves a conversation with nothing unread alone', () async {
      server.addHistory(match, 'Hi!', fromUser: false);

      await openChat();
      await waitForRead();

      expect(match.readByUser, 0);
    });
  });

  group('sending', () {
    test('shows the message while it is on its way', () async {
      final chat = await openChat();

      final sending = chat.send('  Hello there ');
      expect(thread().outgoing.single.text, 'Hello there');
      expect(thread().outgoing.single.status, OutgoingStatus.sending);

      expect(await sending, isA<Sent>());
      expect(thread().outgoing, isEmpty);
      expect(thread().messages.first.body, 'Hello there');
      expect(match.messages.single.body, 'Hello there');
      expect(server.moderationChecks, ['Hello there']);
    });

    test('ignores a message of only spaces', () async {
      final chat = await openChat();

      expect(await chat.send('   '), isA<NothingToSend>());
      expect(match.messages, isEmpty);
    });

    test('keeps messages in the order they were sent', () async {
      final chat = await openChat();

      await Future.wait([
        chat.send('one'),
        chat.send('two'),
        chat.send('three'),
      ]);

      expect(match.messages.map((message) => message.body), [
        'one',
        'two',
        'three',
      ]);
      expect(thread().messages.map((message) => message.body), [
        'three',
        'two',
        'one',
      ]);
    });

    test('asks for another look when moderation warns, and records sending '
        'anyway', () async {
      final chat = await openChat();

      final outcome = await chat.send('Can you send me money?');

      expect(outcome, isA<SendNeedsReview>());
      final review = outcome as SendNeedsReview;
      expect(review.text, 'Can you send me money?');
      expect(review.check.warnings, [
        'This message mentions money. Scammers often ask for it.',
      ]);
      expect(thread().outgoing, isEmpty);
      expect(match.messages, isEmpty);

      expect(await chat.send(review.text, reviewed: true), isA<Sent>());
      expect(match.messages.single.overridden, isTrue);
      // Sending anyway doesn't ask again.
      expect(server.moderationChecks, hasLength(1));
    });

    test('still sends when moderation cannot be reached', () async {
      server.intercept = (options) async {
        if (options.path.endsWith('/moderation/check')) {
          return jsonResponse(
            503,
            errorEnvelope('SERVICE_UNAVAILABLE', 'Try again soon.'),
          );
        }
        return null;
      };
      final chat = await openChat();

      expect(await chat.send('Hello'), isA<Sent>());
      expect(match.messages.single.body, 'Hello');
    });

    test(
      "at today's limit, the message waits, failed, and the upgrade is offered",
      () async {
        server.dailyMessages = 0;
        final chat = await openChat();

        final outcome = await chat.send('Hello');

        expect(outcome, isA<SendNeedsUpgrade>());
        expect((outcome as SendNeedsUpgrade).paywall, isA<DailyLimitReached>());
        final failed = thread().outgoing.single;
        expect(failed.status, OutgoingStatus.failed);
        expect(failed.failure, "You've reached today's message limit.");

        server.dailyMessages = null;
        expect(await chat.retry(failed.localId), isA<Sent>());
        expect(thread().outgoing, isEmpty);
        expect(match.messages.single.body, 'Hello');
      },
    );

    test(
      'a message that never arrives can be tried again, or deleted',
      () async {
        var offline = true;
        server.intercept = (options) async {
          if (offline &&
              options.method == 'POST' &&
              options.path.endsWith('/messages')) {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              error: const SocketException('Network is unreachable'),
            );
          }
          return null;
        };
        final chat = await openChat();

        expect(await chat.send('First'), isA<SendFailed>());
        expect(await chat.send('Second'), isA<SendFailed>());
        final [first, second] = thread().outgoing;
        expect(first.failure, contains('internet connection'));

        offline = false;
        expect(await chat.retry(first.localId), isA<Sent>());
        chat.discard(second.localId);

        expect(thread().outgoing, isEmpty);
        expect(match.messages.map((message) => message.body), ['First']);
      },
    );

    test('sends the same name to the server when it tries again', () async {
      var failSend = true;
      server.intercept = (options) async {
        if (failSend &&
            options.method == 'POST' &&
            options.path.endsWith('/messages')) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.receiveTimeout,
          );
        }
        return null;
      };
      final chat = await openChat();

      expect(await chat.send('Did that send?'), isA<SendFailed>());
      final failed = thread().outgoing.single;

      failSend = false;
      expect(await chat.retry(failed.localId), isA<Sent>());

      // A send that times out has often arrived anyway. The server can only
      // tell that this is the same message, rather than a second one, because
      // both attempts carry the same token.
      // Reading the history uses the same path, so only the sends count.
      final sends = backend
          .requestsTo('/conversations/${match.conversationId}/messages')
          .where((request) => request.method == 'POST')
          .map(
            (request) =>
                (request.data! as Map<String, Object?>)['client_token'],
          )
          .toList();
      expect(sends, hasLength(2));
      expect(sends.first, isNotNull);
      expect(sends.last, sends.first);
    });

    test('two messages are never given the same name', () async {
      final chat = await openChat();

      expect(await chat.send('One'), isA<Sent>());
      expect(await chat.send('Two'), isA<Sent>());

      final tokens = backend
          .requestsTo('/conversations/${match.conversationId}/messages')
          .where((request) => request.method == 'POST')
          .map(
            (request) =>
                (request.data! as Map<String, Object?>)['client_token'],
          )
          .toSet();
      expect(tokens, hasLength(2));
    });

    test('is refused once the conversation has closed', () async {
      match.expiresAt = server.now().subtract(const Duration(hours: 1));
      final chat = await openChat();

      expect(thread().conversation.isWritable, isFalse);
      expect(await chat.send('Hello?'), isA<SendRefused>());
      expect(match.messages, isEmpty);
    });

    test('closes the conversation when the server says it closed', () async {
      final chat = await openChat();
      container.listen(matchesListProvider(false), (_, _) {});
      await container.read(matchesListProvider(false).future);
      server.blocked.add(_sam.id);

      expect(await chat.send('Hello?'), isA<SendRefused>());
      await settle();

      expect(thread().conversation.isWritable, isFalse);
      expect(thread().outgoing, isEmpty);
      // Nothing was ended here, so the match stays listed.
      expect(
        container.read(matchesListProvider(false)).requireValue.items,
        hasLength(1),
      );
    });

    test('uploads a photo, then sends it, keeping it to show', () async {
      final chat = await openChat();
      final photo = PreparedPhoto(
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        width: 2,
        height: 2,
      );

      expect(await chat.sendPhoto(photo), isA<Sent>());

      final sent = match.messages.single;
      expect(sent.type, 'image');
      expect(server.storedUploads.values.single, photo.bytes);
      expect(thread().localPhotos[sent.id], same(photo));
    });

    test('tries a failed photo again without uploading it twice', () async {
      var failSend = true;
      server.intercept = (options) async {
        if (failSend &&
            options.method == 'POST' &&
            options.path.endsWith('/messages')) {
          return jsonResponse(500, errorEnvelope('INTERNAL_ERROR', 'Oops.'));
        }
        return null;
      };
      final chat = await openChat();
      final photo = PreparedPhoto(
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        width: 2,
        height: 2,
      );

      expect(await chat.sendPhoto(photo), isA<SendFailed>());
      final failed = thread().outgoing.single;
      expect(failed.uploadId, isNotNull);

      failSend = false;
      expect(await chat.retry(failed.localId), isA<Sent>());
      expect(server.storedUploads, hasLength(1));
      expect(backend.requestsTo('/media/uploads'), hasLength(1));
    });
  });

  group('live', () {
    test('shows messages as they arrive, and marks them read', () async {
      await goLive();
      await openChat();

      server.receiveMessage(match, 'Are you free on Friday?');
      await settle();

      expect(thread().messages.first.body, 'Are you free on Friday?');
      await waitForRead();
      expect(match.unreadCount, 0);
    });

    test('shows the other person typing until they stop', () async {
      await goLive();
      await openChat();

      server.typingBy(match, isTyping: true);
      await settle();
      expect(thread().peerIsTyping, isTrue);

      server.typingBy(match, isTyping: false);
      await settle();
      expect(thread().peerIsTyping, isFalse);
    });

    test('ignores other conversations', () async {
      final other = FakeMatch(
        id: 'match-p2',
        mode: 'dating',
        person: const FakePerson(id: 'p2', name: 'Alex'),
        isSuperLike: false,
        matchedAt: server.now(),
        expiresAt: server.now().add(const Duration(days: 10)),
      );
      server.matches.add(other);
      await goLive();
      await openChat();

      server
        ..receiveMessage(other, 'Hi from Alex')
        ..typingBy(other, isTyping: true);
      await settle();

      expect(thread().messages, isEmpty);
      expect(thread().peerIsTyping, isFalse);
    });

    test(
      "marks the user's messages read when the other person reads them",
      () async {
        server.addHistory(match, 'Hi Sam', fromUser: true, read: false);
        await goLive();
        await openChat();
        expect(thread().messages.single.readAt, isNull);

        server.readByPerson(match);
        await settle();

        expect(thread().messages.single.readAt, isNotNull);
      },
    );

    test('catches up on what arrived while the connection was away', () async {
      await goLive();
      await openChat();
      final connection = container.read(realtimeConnectionProvider)
        ..setWanted(false);

      server.addHistory(
        match,
        'Sent while you were away',
        fromUser: false,
        read: false,
      );
      connection.setWanted(true);
      await settle();
      await settle();

      expect(thread().messages.first.body, 'Sent while you were away');
    });

    test(
      'tells the other person the user is typing, and has stopped',
      () async {
        await goLive();
        final chat = await openChat();

        chat
          ..draftChanged('H')
          ..draftChanged('He')
          ..draftChanged('Hey');
        expect(server.realtime.sent(ClientEvents.typingStart), [
          {'conversation_id': match.conversationId},
        ]);

        chat.draftChanged('');
        expect(server.realtime.sent(ClientEvents.typingStop), hasLength(1));

        chat.draftChanged('Hi');
        await chat.send('Hi');
        expect(server.realtime.sent(ClientEvents.typingStop), hasLength(2));
      },
    );
  });

  group('ending', () {
    Future<void> openMatches() async {
      container.listen(matchesListProvider(false), (_, _) {});
      await container.read(matchesListProvider(false).future);
    }

    List<String> listed() {
      return [
        for (final match
            in container.read(matchesListProvider(false)).requireValue.items)
          match.id,
      ];
    }

    test('unmatching closes the conversation, and takes the match off the '
        'list', () async {
      final chat = await openChat();
      await openMatches();
      expect(listed(), ['match-p1']);

      expect(await chat.unmatch(), isNull);
      await settle();

      expect(server.matches, isEmpty);
      expect(thread().conversation.isWritable, isFalse);
      expect(listed(), isEmpty);
    });

    test('blocking ends the match too', () async {
      final chat = await openChat();
      await openMatches();

      expect(await chat.block(), isNull);
      await settle();

      expect(server.blocked, {'p1'});
      expect(server.matches, isEmpty);
      expect(listed(), isEmpty);
    });

    test(
      'extending is part of Premium, and reopens an expired match',
      () async {
        match.expiresAt = server.now().subtract(const Duration(hours: 1));
        final chat = await openChat();

        final locked = await chat.extend();
        expect(locked, isA<ExtendNeedsUpgrade>());

        server.isPremium = true;
        final outcome = await chat.extend();

        expect(outcome, isA<Extended>());
        expect(thread().conversation.isWritable, isTrue);
        expect(match.extensionCount, 1);
      },
    );
  });

  test('archiving moves the conversation to the Archived list', () async {
    final chat = await openChat();
    container
      ..listen(matchesListProvider(false), (_, _) {})
      ..listen(matchesListProvider(true), (_, _) {});
    await container.read(matchesListProvider(false).future);
    await container.read(matchesListProvider(true).future);

    expect(await chat.setArchived(true), isNull);
    await settle();

    expect(thread().conversation.isArchived, isTrue);
    expect(
      container.read(matchesListProvider(false)).requireValue.items,
      isEmpty,
    );
    final archived = await container.read(matchesListProvider(true).future);
    expect(archived.items.single.id, 'match-p1');
  });
}
