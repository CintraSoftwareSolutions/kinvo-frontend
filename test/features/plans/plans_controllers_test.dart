import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/auth/auth_providers.dart';
import 'package:kinvo/src/core/realtime/realtime_providers.dart';
import 'package:kinvo/src/features/matches/presentation/controllers/matches_controllers.dart';
import 'package:kinvo/src/features/plans/data/plans_repository.dart';
import 'package:kinvo/src/features/plans/domain/plan.dart';
import 'package:kinvo/src/features/plans/domain/venue.dart';
import 'package:kinvo/src/features/plans/presentation/controllers/plans_controllers.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/auth_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_kinvo_server.dart';
import '../../helpers/test_backend.dart';

void main() {
  // Lists refresh when the app comes back to the screen, which they ask the
  // Flutter binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeKinvoServer server;
  late FakeMatch match;
  late TestBackend backend;
  late ProviderContainer container;

  setUp(() async {
    server = FakeKinvoServer()
      ..completeProfile()
      ..isOnboarded = true;
    match = FakeMatch(
      id: 'match-p1',
      mode: 'dating',
      person: const FakePerson(id: 'p1', name: 'Sam'),
      isSuperLike: false,
      matchedAt: server.now(),
      expiresAt: server.now().add(const Duration(days: 10)),
    );
    server.matches.add(match);
    backend = TestBackend(respond: server.respond, realtime: server.realtime);
    await backend.tokenStore.write(liveSession());
    container = backend.createContainer(clock: server.now);
    await container.read(sessionManagerProvider).ready;
  });

  DateTime tomorrow() => server.now().add(const Duration(days: 1));

  Future<List<String>> placesIn(PlansTab tab) async {
    container.listen(plansListProvider(tab), (_, _) {});
    final list = await container.read(plansListProvider(tab).future);
    return [for (final plan in list.items) plan.placeName];
  }

  /// Waits out the pause before the badge is counted again.
  Future<void> waitForBadge() async {
    await Future<void>.delayed(
      PlansAwaitingAnswerController.settleDelay +
          const Duration(milliseconds: 100),
    );
    await settle();
  }

  PlanActions actions() => container.read(planActionsProvider);

  test('lists plans by where they stand', () async {
    server
      ..planFromPerson(
        match,
        place: 'Proposed',
        at: tomorrow(),
        announce: false,
      )
      ..planFromPerson(
        match,
        place: 'Confirmed',
        at: tomorrow(),
        status: 'confirmed',
        announce: false,
      )
      ..planFromPerson(
        match,
        place: 'Declined',
        at: tomorrow(),
        status: 'declined',
        announce: false,
      );

    expect(await placesIn(PlansTab.upcoming), ['Confirmed']);
    expect(await placesIn(PlansTab.pending), ['Proposed']);
    expect(await placesIn(PlansTab.history), ['Declined']);
    expect(await placesIn(PlansTab.drafts), isEmpty);
  });

  test('a plan is sent, or kept as a draft only the user sees', () async {
    final sent = await actions().create(
      matchId: match.id,
      details: PlanDetails(customLocation: 'Sent', scheduledAt: tomorrow()),
      send: true,
    );
    final kept = await actions().create(
      matchId: match.id,
      details: const PlanDetails(customLocation: 'Kept'),
      send: false,
    );

    expect((sent as PlanSaved).plan.status, PlanStatus.proposed);
    expect((kept as PlanSaved).plan.status, PlanStatus.draft);
    expect(await placesIn(PlansTab.pending), ['Sent']);
    expect(await placesIn(PlansTab.drafts), ['Kept']);
  });

  test('keeps the reasons the server gives for each field', () async {
    final outcome = await actions().create(
      matchId: match.id,
      details: PlanDetails(
        customLocation: 'Too late',
        scheduledAt: server.now().subtract(const Duration(hours: 1)),
      ),
      send: true,
    );

    expect((outcome as PlanRefused).fieldErrors['scheduled_at'], [
      'Pick a time in the future.',
    ]);
  });

  test('a plan the other person suggests arrives at once, and counts on the '
      "Plans tab's badge", () async {
    container.read(realtimeConnectionProvider).setWanted(true);
    await settle();
    expect(await placesIn(PlansTab.pending), isEmpty);
    container.listen(plansAwaitingAnswerProvider, (_, _) {});
    expect(await container.read(plansAwaitingAnswerProvider.future), 0);

    server.planFromPerson(match, place: 'Brunch', at: tomorrow());
    await waitForBadge();

    expect(await placesIn(PlansTab.pending), ['Brunch']);
    expect(container.read(plansAwaitingAnswerProvider).value, 1);
  });

  test('accepting moves it to Upcoming, and clears the badge', () async {
    final proposal = server.planFromPerson(
      match,
      place: 'Brunch',
      at: tomorrow(),
      announce: false,
    );
    container.listen(plansAwaitingAnswerProvider, (_, _) {});
    expect(await container.read(plansAwaitingAnswerProvider.future), 1);
    final plan = await container
        .read(plansRepositoryProvider)
        .fetchPlan(proposal.id);

    final outcome = await actions().answer(plan, accept: true);
    await waitForBadge();

    expect((outcome as PlanSaved).plan.status, PlanStatus.confirmed);
    expect(await placesIn(PlansTab.upcoming), ['Brunch']);
    expect(container.read(plansAwaitingAnswerProvider).value, 0);
  });

  test('changes from a typed place to one from the list', () async {
    server.venues.add(const FakeVenue(id: 'v1', name: 'Blue Bottle'));
    final created = await actions().create(
      matchId: match.id,
      details: PlanDetails(customLocation: 'Typed', scheduledAt: tomorrow()),
      send: true,
    );

    final outcome = await actions().update(
      (created as PlanSaved).plan,
      PlanDetails(venueId: 'v1', scheduledAt: tomorrow()),
    );

    final plan = (outcome as PlanSaved).plan;
    expect(plan.placeName, 'Blue Bottle');
    expect(plan.customLocation, isNull);
    expect(server.plans.single.edits, 1);
  });

  test('sends a draft once its changes are saved', () async {
    final created = await actions().create(
      matchId: match.id,
      details: const PlanDetails(customLocation: 'Later'),
      send: false,
    );

    final outcome = await actions().update(
      (created as PlanSaved).plan,
      PlanDetails(customLocation: 'Later', scheduledAt: tomorrow()),
      send: true,
    );

    expect((outcome as PlanSaved).plan.status, PlanStatus.proposed);
  });

  test('throws a draft away', () async {
    final created = await actions().create(
      matchId: match.id,
      details: const PlanDetails(customLocation: 'Maybe'),
      send: false,
    );
    expect(await placesIn(PlansTab.drafts), ['Maybe']);

    final error = await actions().deleteDraft((created as PlanSaved).plan);
    await settle();

    expect(error, isNull);
    expect(server.plans, isEmpty);
    expect(await placesIn(PlansTab.drafts), isEmpty);
  });

  test('ending the match takes its plans out of Pending', () async {
    server.planFromPerson(
      match,
      place: 'Brunch',
      at: tomorrow(),
      announce: false,
    );
    expect(await placesIn(PlansTab.pending), ['Brunch']);

    container.listen(matchesListProvider(false), (_, _) {});
    await container.read(matchesListProvider(false).future);
    await container.read(matchesListProvider(false).notifier).unmatch(match.id);
    await settle();

    expect(await placesIn(PlansTab.pending), isEmpty);
    expect(await placesIn(PlansTab.history), ['Brunch']);
  });

  test('saving a place shows at once, and goes back when refused', () async {
    server.venues.add(const FakeVenue(id: 'v1', name: 'Blue Bottle'));
    const query = (category: null, savedOnly: false);
    container.listen(venueListProvider(query), (_, _) {});
    final venues = await container.read(venueListProvider(query).future);

    server.intercept = (options) async {
      if (options.path.endsWith('/save')) {
        return jsonResponse(
          503,
          errorEnvelope('SERVICE_UNAVAILABLE', 'Please try again shortly.'),
        );
      }
      return null;
    };
    final error = await container
        .read(venueListProvider(query).notifier)
        .toggleSaved(venues.single);

    expect(error, 'Please try again shortly.');
    expect(
      container.read(venueListProvider(query)).requireValue.single.isSaved,
      isFalse,
    );

    server.intercept = null;
    await container
        .read(venueListProvider(query).notifier)
        .toggleSaved(venues.single);
    expect(server.savedVenues, {'v1'});
  });

  group('a saved place shows the same in every list', () {
    const cafes = (category: VenueCategory.cafe, savedOnly: false);

    setUp(() {
      server.venues.addAll(const [
        FakeVenue(id: 'v1', name: 'Blue Bottle'),
        FakeVenue(id: 'v2', name: 'Hyde Park', category: 'park'),
      ]);
    });

    Future<List<Venue>> load(VenueQuery query) {
      container.listen(venueListProvider(query), (_, _) {});
      return container.read(venueListProvider(query).future);
    }

    Venue shown(VenueQuery query, String id) {
      return container
          .read(venueListProvider(query))
          .requireValue
          .singleWhere((venue) => venue.id == id);
    }

    test(
      'saved in one list, it is under Saved and saved in the rest',
      () async {
        final cafeList = await load(cafes);
        expect(await load(nearbyVenues), hasLength(2));
        expect(await load(savedVenues), isEmpty);

        await container
            .read(venueListProvider(cafes).notifier)
            .toggleSaved(cafeList.single);
        await settle();

        final saved = await container.read(
          venueListProvider(savedVenues).future,
        );
        expect([for (final venue in saved) venue.name], ['Blue Bottle']);
        expect(shown(nearbyVenues, 'v1').isSaved, isTrue);
        expect(shown(nearbyVenues, 'v2').isSaved, isFalse);
        expect(shown(cafes, 'v1').isSaved, isTrue);
      },
    );

    test(
      'taken off under Saved, it leaves Saved and is unsaved in the rest',
      () async {
        server.savedVenues.add('v1');
        final nearby = await load(nearbyVenues);
        expect(nearby.first.isSaved, isTrue);
        final saved = await load(savedVenues);

        final unsaving = container
            .read(venueListProvider(savedVenues).notifier)
            .toggleSaved(saved.single);
        // Until the server agrees it stays, so a mistaken tap can be undone.
        expect(shown(savedVenues, 'v1').isSaved, isFalse);

        expect(await unsaving, isNull);
        await settle();
        expect(server.savedVenues, isEmpty);
        expect(
          container.read(venueListProvider(savedVenues)).requireValue,
          isEmpty,
        );
        expect(shown(nearbyVenues, 'v1').isSaved, isFalse);
      },
    );

    test('a refused save changes no other list', () async {
      final nearby = await load(nearbyVenues);
      await load(savedVenues);
      server.intercept = (options) async => options.path.endsWith('/save')
          ? jsonResponse(
              503,
              errorEnvelope('SERVICE_UNAVAILABLE', 'Please try again shortly.'),
            )
          : null;

      await container
          .read(venueListProvider(nearbyVenues).notifier)
          .toggleSaved(nearby.first);

      expect(shown(nearbyVenues, 'v1').isSaved, isFalse);
      expect(
        container.read(venueListProvider(savedVenues)).requireValue,
        isEmpty,
      );
    });

    test(
      'a save still lands under Saved when its list closes meanwhile',
      () async {
        final saving = Completer<void>();
        server.intercept = (options) async {
          if (options.path.endsWith('/save')) await saving.future;
          return null;
        };
        final cafeSubscription = container.listen(
          venueListProvider(cafes),
          (_, _) {},
        );
        final cafeList = await container.read(venueListProvider(cafes).future);
        await load(savedVenues);

        final toggled = container
            .read(venueListProvider(cafes).notifier)
            .toggleSaved(cafeList.single);
        // The user moves to another list while the save is on its way.
        cafeSubscription.close();
        await settle();
        saving.complete();

        expect(await toggled, isNull);
        await settle();
        final saved = await container.read(
          venueListProvider(savedVenues).future,
        );
        expect([for (final venue in saved) venue.name], ['Blue Bottle']);
      },
    );
  });
}
