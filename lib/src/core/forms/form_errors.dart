import '../network/api_exception.dart';

/// Shown when submitting fails for a reason the app didn't expect.
const unexpectedFailureMessage = 'Something went wrong. Please try again.';

/// What to tell the user when saving one thing failed: the server's message
/// about [field], by its name in the request body, when it gave one, and
/// otherwise the best message it gave.
String saveFailureMessage(Object error, {String? field}) {
  return switch (error) {
    ApiErrorException(:final fieldErrors, :final message) =>
      [
            ...?fieldErrors[field],
            for (final messages in fieldErrors.values) ...messages,
          ].firstOrNull ??
          message,
    ApiException(:final message) => message,
    _ => unexpectedFailureMessage,
  };
}

/// A form field the API reports validation errors for.
abstract interface class ApiFormField {
  /// The field's name in the request body, which the API's field errors use.
  String get wireName;
}

/// A validation failure sorted onto a form: an error for each field it names,
/// and a message for the form as a whole when there's more to say.
typedef SortedFieldErrors<F> = ({
  Map<F, String> fieldErrors,
  String? formError,
});

/// Sorts the errors of a `VALIDATION_FAILED` response onto [fields].
///
/// Errors about anything the form doesn't show, such as the device id, become
/// one message for the whole form. So does the server's summary when it names
/// no field at all, so the user is never left without an explanation.
SortedFieldErrors<F> sortFieldErrors<F extends ApiFormField>(
  ApiErrorException error,
  List<F> fields,
) {
  final fieldsByWireName = {for (final field in fields) field.wireName: field};
  final fieldErrors = <F, String>{};
  final otherMessages = <String>[];

  for (final MapEntry(key: name, value: messages)
      in error.fieldErrors.entries) {
    if (messages.isEmpty) continue;
    if (fieldsByWireName[name] case final field?) {
      fieldErrors[field] = messages.first;
    } else {
      otherMessages.addAll(messages);
    }
  }

  final String? formError;
  if (otherMessages.isNotEmpty) {
    formError = otherMessages.join('\n');
  } else if (fieldErrors.isEmpty) {
    formError = error.message;
  } else {
    formError = null;
  }
  return (fieldErrors: fieldErrors, formError: formError);
}
