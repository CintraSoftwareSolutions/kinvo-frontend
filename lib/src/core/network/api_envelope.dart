import 'api_error_code.dart';

/// A decoded JSON object.
typedef JsonMap = Map<String, Object?>;

/// The `error` object of a failure envelope.
typedef ApiErrorBody = ({ApiErrorCode code, String message, JsonMap? details});

/// The contents of a paginated success envelope.
typedef ApiListBody = ({
  List<Object?> items,
  String? nextCursor,
  bool hasMore,
  int limit,
});

/// Reads the envelope that wraps every backend response:
///
/// ```json
/// { "success": true,  "data": { } or [ ], "meta": { "pagination": { } } or null }
/// { "success": false, "error": { "code": "...", "message": "...", "details": { } or null } }
/// ```
///
/// The readers throw [FormatException] when a body doesn't have the expected
/// shape. Messages describe the shape only, never values, because bodies can
/// contain personal data.
abstract final class ApiEnvelope {
  /// Returns the `data` object of a success envelope.
  static JsonMap readData(Object? body) {
    if (body case {'success': true, 'data': final JsonMap data}) {
      return data;
    }
    throw FormatException(
      'Expected a success envelope with an object in "data", '
      'but got ${_describe(body)}.',
    );
  }

  /// Returns the items and pagination of a paginated success envelope.
  static ApiListBody readList(Object? body) {
    if (body case {
      'success': true,
      'data': final List<Object?> items,
      'meta': {
        'pagination': {
          'next_cursor': final String? nextCursor,
          'has_more': final bool hasMore,
          'limit': final int limit,
        },
      },
    }) {
      return (
        items: items,
        nextCursor: nextCursor,
        hasMore: hasMore,
        limit: limit,
      );
    }
    throw FormatException(
      'Expected a paginated success envelope, but got ${_describe(body)}.',
    );
  }

  /// Returns the error from a failure envelope, or `null` when [body] isn't
  /// one, for example a CDN error page.
  static ApiErrorBody? tryReadError(Object? body) {
    if (body case {'success': false, 'error': final JsonMap error}) {
      if (error case {
        'code': final String code,
        'message': final String message,
      }) {
        final details = error['details'];
        return (
          code: ApiErrorCode.fromWireValue(code),
          message: message,
          details: details is JsonMap ? details : null,
        );
      }
    }
    return null;
  }

  static String _describe(Object? body) => switch (body) {
    null => 'an empty body',
    Map<Object?, Object?>(:final keys) => 'an object with keys $keys',
    List<Object?>() => 'a list',
    String() => 'text',
    _ => 'a ${body.runtimeType}',
  };
}
