import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/media/photo_processing.dart';
import 'package:kinvo/src/features/matches/presentation/controllers/matches_controllers.dart';
import 'package:kinvo/src/features/safety/data/safety_repository.dart';
import 'package:kinvo/src/features/safety/presentation/controllers/report_controller.dart';

import '../../helpers/auth_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_kinvo_server.dart';
import '../../helpers/test_backend.dart';

const _sam = FakePerson(id: 'p1', name: 'Sam');

const _target = ReportTarget(
  userId: 'p1',
  displayName: 'Sam',
  matchId: 'match-p1',
  context: ReportContext.profile,
);

PreparedPhoto _screenshot(int seed) {
  return PreparedPhoto(
    bytes: Uint8List.fromList([seed, seed + 1, seed + 2]),
    width: 3,
    height: 1,
  );
}

void main() {
  late FakeKinvoServer server;
  late TestBackend backend;
  late ProviderContainer container;

  setUp(() {
    server = FakeKinvoServer()
      ..completeProfile()
      ..isOnboarded = true
      ..matches.add(
        FakeMatch(
          id: 'match-p1',
          mode: 'dating',
          person: _sam,
          isSuperLike: false,
          matchedAt: DateTime.utc(2026, 9, 16),
          expiresAt: DateTime.utc(2026, 9, 30),
        ),
      );
    backend = TestBackend(respond: server.respond);
    container = backend.createContainer();
  });

  ReportFormController form() {
    container.listen(reportFormProvider('p1'), (_, _) {});
    return container.read(reportFormProvider('p1').notifier);
  }

  ReportForm state() => container.read(reportFormProvider('p1'));

  test('offers the reasons the server lists', () async {
    final reasons = await container.read(reportReasonsProvider.future);

    expect(reasons.map((reason) => reason.label), [
      'Harassment or abuse',
      'Fake profile',
      'Spam or scam',
      'Safety concern',
    ]);
  });

  test('needs a reason before anything is sent', () async {
    final controller = form();

    expect(await controller.submit(_target), isNull);

    expect(state().error, 'Choose what happened.');
    expect(server.reports, isEmpty);

    controller.selectReason('harassment');
    expect(state().error, isNull);
  });

  test('files the report with what happened and screenshots', () async {
    final controller = form()
      ..selectReason('harassment')
      ..setDetails('  Kept messaging after I said no.  ')
      ..addEvidence(_screenshot(1))
      ..addEvidence(_screenshot(2))
      ..setAlsoBlock(false);

    expect(await controller.submit(_target), ReportResult.reported);

    final report = server.reports.single;
    expect(report['reported_id'], 'p1');
    expect(report['reason'], 'harassment');
    expect(report['description'], 'Kept messaging after I said no.');
    expect(report['context_type'], 'profile');
    expect(report['also_block'], isFalse);
    expect(report['evidence_asset_ids'], hasLength(2));
    expect(server.storedUploads, hasLength(2));
    expect(server.blocked, isEmpty);
  });

  test('takes at most five screenshots, and can drop one', () {
    final controller = form();
    for (var i = 0; i < 7; i++) {
      controller.addEvidence(_screenshot(i));
    }
    expect(state().evidence, hasLength(ReportDraft.maxEvidence));
    expect(state().canAddEvidence, isFalse);

    controller.removeEvidence(0);
    expect(state().evidence, hasLength(4));
    expect(state().evidence.first.bytes, _screenshot(1).bytes);
  });

  test(
    'blocks by default, which ends the match wherever it is listed',
    () async {
      container.listen(matchesListProvider(false), (_, _) {});
      await container.read(matchesListProvider(false).future);
      final controller = form()..selectReason('spam_scam');

      expect(await controller.submit(_target), ReportResult.reportedAndBlocked);
      await settle();

      expect(server.blocked, {'p1'});
      expect(
        container.read(matchesListProvider(false)).requireValue.items,
        isEmpty,
      );
    },
  );

  test('keeps the form when the report cannot be sent', () async {
    server.intercept = (options) async {
      if (options.path.endsWith('/reports')) {
        return jsonResponse(
          503,
          errorEnvelope('SERVICE_UNAVAILABLE', 'Please try again shortly.'),
        );
      }
      return null;
    };
    final controller = form()
      ..selectReason('safety_concern')
      ..setDetails('Details');

    expect(await controller.submit(_target), isNull);

    expect(state().error, 'Please try again shortly.');
    expect(state().isSubmitting, isFalse);
    expect(state().reason, 'safety_concern');
    expect(state().details, 'Details');
  });
}
