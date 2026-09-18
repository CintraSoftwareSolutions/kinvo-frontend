import 'package:flutter/material.dart';

import '../../../core/time/calendar_date.dart';
import '../domain/account_rules.dart';

/// Asks for a date of birth. Returns `null` when the user cancels.
///
/// Opens on [initial] when there is one, otherwise on the youngest age Kinvo
/// allows, and starts by choosing the year: a birthday is found fastest by its
/// year. Any date up to [today] can be chosen, so someone too young is told
/// why rather than being unable to pick their real birthday.
Future<CalendarDate?> pickDateOfBirth(
  BuildContext context, {
  required DateTime today,
  CalendarDate? initial,
}) async {
  final picked = await showDatePicker(
    context: context,
    initialDate:
        initial?.toDateTime() ??
        DateTime(today.year - AccountRules.minimumAge, today.month, today.day),
    firstDate: DateTime(1900),
    lastDate: today,
    currentDate: today,
    initialDatePickerMode: DatePickerMode.year,
    helpText: 'Date of birth',
  );
  return picked == null ? null : CalendarDate.fromDateTime(picked);
}

/// How a date of birth reads in a form, for example "Sep 15, 2008".
String formatDateOfBirth(BuildContext context, CalendarDate dateOfBirth) {
  // The short form includes the year; the medium one doesn't.
  return MaterialLocalizations.of(
    context,
  ).formatShortDate(dateOfBirth.toDateTime());
}
