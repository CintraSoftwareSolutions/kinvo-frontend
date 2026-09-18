import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/time/calendar_date.dart';

void main() {
  test('is written as YYYY-MM-DD', () {
    expect(CalendarDate(2008, 3, 5).toIsoString(), '2008-03-05');
    expect(CalendarDate(987, 12, 31).toIsoString(), '0987-12-31');
  });

  test('takes the date a DateTime falls on in its own time zone', () {
    expect(
      CalendarDate.fromDateTime(DateTime(2008, 3, 5, 23, 59)),
      CalendarDate(2008, 3, 5),
    );
    expect(
      CalendarDate.fromDateTime(DateTime.utc(2008, 3, 5, 0, 1)),
      CalendarDate(2008, 3, 5),
    );
  });

  test('reads the dates the API sends', () {
    expect(CalendarDate.tryParse('1995-07-04'), CalendarDate(1995, 7, 4));
    expect(CalendarDate.tryParse('2024-02-29'), CalendarDate(2024, 2, 29));
  });

  test('reads nothing else as a date', () {
    for (final value in [
      '',
      '1995-7-4',
      '04/07/1995',
      '1995-07-04T00:00:00Z',
      '2025-02-29',
      '1995-13-01',
    ]) {
      expect(CalendarDate.tryParse(value), isNull, reason: value);
    }
  });

  test('turns back into local midnight', () {
    expect(CalendarDate(2008, 3, 5).toDateTime(), DateTime(2008, 3, 5));
  });

  group('yearsUntil', () {
    test('goes up on the anniversary', () {
      final born = CalendarDate(2008, 9, 15);

      expect(born.yearsUntil(CalendarDate(2026, 9, 14)), 17);
      expect(born.yearsUntil(CalendarDate(2026, 9, 15)), 18);
      expect(born.yearsUntil(CalendarDate(2026, 12, 31)), 18);
    });

    test('counts a 29 February birthday from 1 March in other years', () {
      final born = CalendarDate(2004, 2, 29);

      expect(born.yearsUntil(CalendarDate(2022, 2, 28)), 17);
      expect(born.yearsUntil(CalendarDate(2022, 3, 1)), 18);
      expect(born.yearsUntil(CalendarDate(2024, 2, 29)), 20);
    });
  });

  test('orders dates by year, then month, then day', () {
    expect(
      CalendarDate(2026, 1, 1).isAfter(CalendarDate(2025, 12, 31)),
      isTrue,
    );
    expect(CalendarDate(2026, 2, 1).isAfter(CalendarDate(2026, 1, 31)), isTrue);
    expect(CalendarDate(2026, 1, 2).isAfter(CalendarDate(2026, 1, 1)), isTrue);
    expect(CalendarDate(2026, 1, 1).isAfter(CalendarDate(2026, 1, 1)), isFalse);
  });

  test('refuses dates that do not exist', () {
    expect(() => CalendarDate(2025, 2, 29), throwsA(isA<AssertionError>()));
    expect(() => CalendarDate(2026, 4, 31), throwsA(isA<AssertionError>()));
    expect(() => CalendarDate(2026, 13, 1), throwsA(isA<AssertionError>()));
    expect(CalendarDate(2024, 2, 29).day, 29);
  });
}
