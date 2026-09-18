import 'package:flutter/foundation.dart';

/// A day on the calendar, with no time of day or time zone.
///
/// A date of birth is the same date wherever the user is. Passing it around as
/// a [DateTime] invites converting it between time zones, which can move it by
/// a day.
@immutable
final class CalendarDate implements Comparable<CalendarDate> {
  /// [month] and [day] start at 1 and must name a real date.
  CalendarDate(this.year, this.month, this.day)
    : assert(
        _isValid(year, month, day),
        'There is no calendar date $year-$month-$day.',
      );

  /// The date [dateTime] falls on, in [dateTime]'s own time zone.
  CalendarDate.fromDateTime(DateTime dateTime)
    : this(dateTime.year, dateTime.month, dateTime.day);

  /// Reads a `YYYY-MM-DD` date, as the API sends them. Returns `null` for
  /// anything else, including dates that don't exist.
  static CalendarDate? tryParse(String value) {
    final match = _isoPattern.firstMatch(value);
    if (match == null) return null;

    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    return _isValid(year, month, day) ? CalendarDate(year, month, day) : null;
  }

  static final _isoPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  final int year;
  final int month;
  final int day;

  /// Midnight at the start of this date, in local time.
  DateTime toDateTime() => DateTime(year, month, day);

  /// The `YYYY-MM-DD` form the API uses.
  String toIsoString() {
    final paddedYear = year.toString().padLeft(4, '0');
    final paddedMonth = month.toString().padLeft(2, '0');
    final paddedDay = day.toString().padLeft(2, '0');
    return '$paddedYear-$paddedMonth-$paddedDay';
  }

  /// Whole years from this date until [date], counted the way ages are.
  ///
  /// The count goes up on the anniversary. In years without 29 February,
  /// someone born on that day turns a year older on 1 March, as the backend
  /// counts it.
  int yearsUntil(CalendarDate date) {
    final years = date.year - year;
    final beforeAnniversary =
        date.month < month || (date.month == month && date.day < day);
    return beforeAnniversary ? years - 1 : years;
  }

  bool isAfter(CalendarDate other) => compareTo(other) > 0;

  @override
  int compareTo(CalendarDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarDate &&
        other.year == year &&
        other.month == month &&
        other.day == day;
  }

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIsoString();

  static bool _isValid(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1) return false;
    // Day 0 of the next month is the last day of this one.
    final daysInMonth = DateTime.utc(year, month + 1, 0).day;
    return day <= daysInMonth;
  }
}
