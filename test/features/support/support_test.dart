import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/config/server_config.dart';
import 'package:kinvo/src/core/navigation/app_routes.dart';
import 'package:kinvo/src/features/discovery/presentation/screens/discover_screen.dart';
import 'package:kinvo/src/features/more/presentation/screens/safety_center_screen.dart';
import 'package:kinvo/src/features/more/presentation/screens/support_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_kinvo_server.dart';

/// Support and the pages Kinvo publishes. Every row and link leads somewhere
/// real, and one whose page doesn't exist yet isn't shown at all.
const _help = 'https://kinvo.app/help';
const _guidelines = 'https://kinvo.app/guidelines';
const _terms = 'https://kinvo.app/terms';
const _privacy = 'https://kinvo.app/privacy';

FakeKinvoServer _signedInServer() {
  return FakeKinvoServer()
    ..completeProfile()
    ..isOnboarded = true;
}

FakeKinvoServer _publishing(FakeKinvoServer server) {
  return server
    ..supportEmail = 'help@kinvo.app'
    ..helpUrl = _help
    ..guidelinesUrl = _guidelines
    ..termsUrl = _terms
    ..privacyUrl = _privacy;
}

Future<AppHarness> _openSupport(
  WidgetTester tester,
  FakeKinvoServer server,
) async {
  final app = await pumpKinvoApp(
    tester,
    savedSession: liveSession(),
    respond: server.respond,
    clock: server.now,
  );
  await app.pumpUntilFound(find.byType(DiscoverScreen));
  await app.pumpUntilLoaded();
  // Under the More tab, which loads as it opens.
  app.router.go(AppRoutes.support);
  await app.pumpUntilFound(find.byType(SupportScreen));
  await app.pumpUntilLoaded();
  return app;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  group('Support', () {
    testWidgets('shows only what leads somewhere', (tester) async {
      final app = await _openSupport(tester, _signedInServer());

      // The Safety Center is always there; nothing is published yet.
      expect(find.text('Safety Center'), findsOneWidget);
      for (final row in [
        'Help centre',
        'Community guidelines',
        'Terms of service',
        'Privacy policy',
        'Email support',
      ]) {
        expect(find.text(row), findsNothing, reason: row);
      }

      await _tap(tester, find.text('Safety Center'));
      await app.pumpUntilFound(find.byType(SafetyCenterScreen));
      await app.pumpUntilLoaded();
    });

    testWidgets('opens each published page', (tester) async {
      final app = await _openSupport(tester, _publishing(_signedInServer()));
      await app.pumpUntilFound(find.text('Privacy policy'));

      for (final row in [
        'Help centre',
        'Community guidelines',
        'Terms of service',
        'Privacy policy',
      ]) {
        await _tap(tester, find.text(row));
      }

      expect(app.backend.externalLinks.pages.map((page) => '$page'), [
        _help,
        _guidelines,
        _terms,
        _privacy,
      ]);
    });

    testWidgets('writes to support in the mail app', (tester) async {
      final app = await _openSupport(tester, _publishing(_signedInServer()));
      await app.pumpUntilFound(find.text('Email support'));

      await _tap(tester, find.text('Email support'));

      expect(app.backend.externalLinks.emails.single, (
        to: 'help@kinvo.app',
        subject: 'Kinvo support',
      ));
    });

    testWidgets('with no mail app, gives the address to copy', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      final app = await _openSupport(tester, _publishing(_signedInServer()));
      app.backend.externalLinks.canWriteEmail = false;
      await app.pumpUntilFound(find.text('Email support'));

      await _tap(tester, find.text('Email support'));
      await app.pumpUntilFound(find.text('Copy address'));
      expect(
        find.text(
          "There's no mail app on this phone. Write to help@kinvo.app.",
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Copy address'));
      await tester.pumpAndSettle();

      expect(copied, 'help@kinvo.app');
    });
  });

  group('the welcome screen', () {
    const agreement = 'By continuing, you agree to our ';

    testWidgets('asks agreement to nothing until both pages exist', (
      tester,
    ) async {
      final server = FakeKinvoServer()..termsUrl = _terms;
      final app = await pumpKinvoApp(tester, respond: server.respond);
      await app.pumpUntilFound(find.text('Log In'));
      await tester.pump(const Duration(seconds: 1));

      // Terms alone isn't enough to say what signing up agrees to.
      expect(find.text(agreement), findsNothing);
    });

    testWidgets('links to both once published', (tester) async {
      final server = FakeKinvoServer()
        ..termsUrl = _terms
        ..privacyUrl = _privacy;
      final app = await pumpKinvoApp(tester, respond: server.respond);
      await app.pumpUntilFound(find.text(agreement));

      await tester.tap(find.text('Terms'));
      await tester.tap(find.text('Privacy Policy'));
      await tester.pump();

      expect(app.backend.externalLinks.pages.map((page) => '$page'), [
        _terms,
        _privacy,
      ]);
    });
  });

  group('SupportLinks', () {
    test('keeps only real addresses, and only secure pages', () {
      final links = SupportLinks.fromJson({
        'email': 'not an address',
        'help_url': 'http://kinvo.app/help',
        'guidelines_url': 'javascript:alert(1)',
        'terms_url': _terms,
        'privacy_url': null,
      });

      expect(links.email, isNull);
      expect(links.helpCentre, isNull);
      expect(links.guidelines, isNull);
      expect(links.terms, Uri.parse(_terms));
      expect(links.privacy, isNull);
      expect(links.hasLegalPages, isFalse);
    });

    test('are none when the server sends none', () {
      final links = SupportLinks.fromJson(null);

      expect(links.email, isNull);
      expect(links.terms, isNull);
    });
  });

  group('SignInMethods', () {
    test('offers a method only on an explicit yes', () {
      final methods = SignInMethods.fromJson({
        'email': true,
        'phone': 'true',
        'google': true,
      });

      expect(methods.phone, isFalse);
      expect(methods.google, isTrue);
      expect(methods.apple, isFalse);
      expect(
        SignInMethods.fromJson(null).google,
        isFalse,
        reason: 'an older server says nothing, and nothing is assumed',
      );
    });
  });
}
