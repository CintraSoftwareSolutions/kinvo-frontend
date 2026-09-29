import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/theme/app_theme.dart';
import 'package:kinvo/src/core/widgets/count_badge.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    int count, {
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(Brightness.light),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Center(child: CountBadge(count)),
        ),
      ),
    );
  }

  testWidgets('draws nothing when nothing is waiting', (tester) async {
    await show(tester, 0);

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('shows the count, and "99+" past ninety-nine', (tester) async {
    await show(tester, 7);
    expect(find.text('7'), findsOneWidget);

    await show(tester, 99);
    expect(find.text('99'), findsOneWidget);

    await show(tester, 150);
    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('grows with larger text, but only so far', (tester) async {
    await show(tester, 3, textScale: 2);

    final text = tester.widget<Text>(find.text('3'));
    expect(text.textScaler?.scale(10), closeTo(13, 0.001));
  });

  testWidgets('leaves the count to what it is on, for screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await show(tester, 4);

    expect(find.bySemanticsLabel('4'), findsNothing);
    semantics.dispose();
  });
}
