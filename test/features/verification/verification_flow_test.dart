import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/media/media_uploader.dart';
import 'package:kinvo/src/core/media/photo_picker.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';
import 'package:kinvo/src/features/verification/presentation/verification_capture_screen.dart';
import 'package:kinvo/src/features/verification/presentation/verification_success_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/device_fakes.dart';
import '../../helpers/fake_kinvo_server.dart';

void main() {
  late FakeKinvoServer server;

  setUp(() {
    server = FakeKinvoServer()..isOnboarded = true;
  });

  Future<AppHarness> openVerification(WidgetTester tester) async {
    final app = await pumpKinvoApp(
      tester,
      savedSession: liveSession(),
      respond: server.respond,
      clock: server.now,
    );
    await app.pumpUntilFound(find.byType(DiscoverScreen));
    await app.pumpUntilLoaded();
    app.router.go(AppRoutes.verificationMethods);
    await app.pumpUntilFound(find.text('Get verified'));
    return app;
  }

  /// Goes through choosing a method and sending the photo.
  Future<void> sendSelfie(WidgetTester tester, AppHarness app) async {
    await tester.tap(find.text('Photo verification'));
    await app.pumpUntilFound(find.byType(VerificationCaptureScreen));

    await tester.tap(find.text('Take a photo'));
    await app.pumpUntilFound(find.text('Send for review'));

    await tester.tap(find.text('Send for review'));
    await app.pumpUntilFound(find.byType(VerificationSuccessScreen));
  }

  testWidgets('a selfie is taken, uploaded and sent for review', (
    tester,
  ) async {
    final app = await openVerification(tester);
    await sendSelfie(tester, app);

    // The camera was asked for the front lens, not the one pointing away.
    expect(app.backend.photoPicker.requests, [PhotoSource.selfie]);

    // The picture went straight to storage; only its id reached the API.
    expect(server.storedUploads, hasLength(1));
    final upload = app.backend.requestsTo('/media/uploads').first;
    expect(
      (upload.data! as Map<String, Object?>)['purpose'],
      UploadPurpose.verificationDocument.wireValue,
    );
    expect(
      app.backend.requestsTo('/verification').last.data,
      isNot(contains('bytes')),
    );

    final record = server.verification!;
    expect(record.method, 'photo');
    expect(record.documentUploadId, isNotNull);
    expect(record.submittedAt, isNotNull);

    // Coming back from the "sent" screen, the first screen now says so
    // instead of offering to start again.
    await tester.tap(find.text('Done'));
    await app.pumpUntilFound(find.text('Waiting to be checked'));
    expect(find.text('Photo verification'), findsNothing);
  });

  testWidgets('an ID is chosen from the photo library', (tester) async {
    final app = await openVerification(tester);
    app.backend.photoPicker.nextPhoto = testPhoto;

    await tester.tap(find.text('ID verification'));
    await app.pumpUntilFound(find.byType(VerificationCaptureScreen));
    expect(find.text('Photograph your ID'), findsOneWidget);

    await tester.tap(find.text('Add a photo of your ID'));
    // An ID may already be photographed, so this one asks where from.
    await app.pumpUntilFound(find.text('Choose from your photos'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Choose from your photos'));
    await app.pumpUntilFound(find.text('Send for review'));

    expect(app.backend.photoPicker.requests, [PhotoSource.library]);
    expect(server.verification!.method, 'government_id');
  });

  testWidgets('a moderator approving it shows the badge', (tester) async {
    final app = await openVerification(tester);
    await sendSelfie(tester, app);
    await tester.tap(find.text('Done'));
    await app.pumpUntilFound(find.text('Waiting to be checked'));

    server.reviewVerification(approve: true);
    await tester.tap(find.text('Check again'));
    await app.pumpUntilFound(find.text("You're verified"));

    expect(find.textContaining('badge on your profile'), findsOneWidget);
  });

  testWidgets('a rejection says why, and another attempt can be made', (
    tester,
  ) async {
    final app = await openVerification(tester);
    await sendSelfie(tester, app);
    await tester.tap(find.text('Done'));
    await app.pumpUntilFound(find.text('Waiting to be checked'));

    server.reviewVerification(
      approve: false,
      reason: 'The photo was too dark to match.',
    );
    await tester.tap(find.text('Check again'));
    await app.pumpUntilFound(find.text('Not approved'));

    expect(find.text('The photo was too dark to match.'), findsOneWidget);
    // The methods are offered again underneath, so it is one tap to retry.
    await tester.tap(find.text('Photo verification'));
    await app.pumpUntilFound(find.byType(VerificationCaptureScreen));
    expect(server.verification!.status, 'pending');
  });

  testWidgets('a half-finished attempt is continued, not started again', (
    tester,
  ) async {
    final app = await openVerification(tester);

    await tester.tap(find.text('Photo verification'));
    await app.pumpUntilFound(find.byType(VerificationCaptureScreen));
    // Leaves before taking the photo, as a real interruption would.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await app.pumpUntilFound(find.text('Finish your verification'));

    expect(find.text('Get verified'), findsNothing);
    await tester.tap(find.text('Continue'));
    await app.pumpUntilFound(find.byType(VerificationCaptureScreen));

    // Still the one attempt: continuing did not create a second. (The
    // reads of the same path are not attempts.)
    expect(
      app.backend
          .requestsTo('/verification')
          .where((request) => request.method == 'POST'),
      hasLength(1),
    );
  });

  testWidgets('a picture that cannot be read says so and nothing is sent', (
    tester,
  ) async {
    final app = await openVerification(tester);
    app.backend.photoPicker.nextError = const PhotoPickException(
      PhotoPickFailure.unreadable,
    );

    await tester.tap(find.text('Photo verification'));
    await app.pumpUntilFound(find.byType(VerificationCaptureScreen));
    await tester.tap(find.text('Take a photo'));
    await app.pumpUntilFound(find.text(PhotoPickFailure.unreadable.message));

    expect(server.storedUploads, isEmpty);
    expect(find.text('Send for review'), findsNothing);
  });

  testWidgets('an account that is already verified is told, not asked', (
    tester,
  ) async {
    server.isVerified = true;
    final app = await pumpKinvoApp(
      tester,
      savedSession: liveSession(),
      respond: server.respond,
      clock: server.now,
    );
    await app.pumpUntilFound(find.byType(DiscoverScreen));
    await app.pumpUntilLoaded();
    app.router.go(AppRoutes.verificationMethods);
    await app.pumpUntilFound(find.text("You're verified"));

    expect(find.text('Photo verification'), findsNothing);
  });
}
