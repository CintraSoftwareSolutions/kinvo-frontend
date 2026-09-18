import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/forms/form_errors.dart';
import 'package:kinvo/src/core/network/api_error_code.dart';
import 'package:kinvo/src/core/network/api_exception.dart';

enum _Field implements ApiFormField {
  email('email'),
  name('display_name');

  const _Field(this.wireName);

  @override
  final String wireName;
}

ApiErrorException _validationFailed(Map<String, Object?> details) {
  return ApiErrorException(
    code: ApiErrorCode.validationFailed,
    message: 'Some fields need attention.',
    statusCode: 400,
    details: details,
  );
}

void main() {
  test('puts the first error for each field under that field', () {
    final sorted = sortFieldErrors(
      _validationFailed({
        'email': ['Enter a valid email address.', 'That email is too long.'],
        'display_name': ['Enter your name.'],
      }),
      _Field.values,
    );

    expect(sorted.fieldErrors, {
      _Field.email: 'Enter a valid email address.',
      _Field.name: 'Enter your name.',
    });
    expect(sorted.formError, isNull);
  });

  test('errors about anything the form does not show go to the form', () {
    final sorted = sortFieldErrors(
      _validationFailed({
        'email': ['Enter a valid email address.'],
        'device_id': ['Too long.'],
        '_': ['Try again.'],
      }),
      _Field.values,
    );

    expect(sorted.fieldErrors, {_Field.email: 'Enter a valid email address.'});
    expect(sorted.formError, 'Too long.\nTry again.');
  });

  test("falls back to the server's summary when no field is named", () {
    final sorted = sortFieldErrors(_validationFailed({}), _Field.values);

    expect(sorted.fieldErrors, isEmpty);
    expect(sorted.formError, 'Some fields need attention.');
  });
}
