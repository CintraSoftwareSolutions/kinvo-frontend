import 'package:flutter_test/flutter_test.dart';

import 'package:kinvo/src/app.dart';

void main() {
  testWidgets('renders welcome screen actions', (tester) async {
    await tester.pumpWidget(const KinvoApp());
    await tester.pumpAndSettle();

    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Explore Demo'), findsOneWidget);
  });
}
