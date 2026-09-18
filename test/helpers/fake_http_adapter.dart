import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Produces the response for one request, or throws to simulate a failure.
typedef FakeResponder = Future<ResponseBody> Function(RequestOptions options);

/// A Dio adapter that answers from a callback, so API tests never touch the
/// network. Every request it receives is recorded in [requests].
final class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this._respond);

  final FakeResponder _respond;

  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return _respond(options);
  }

  @override
  void close({bool force = false}) {}
}

/// A response whose body is [body] encoded as JSON.
ResponseBody jsonResponse(
  int statusCode,
  Object? body, {
  Map<String, List<String>> headers = const {},
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      ...headers,
    },
  );
}

/// A response with a plain-text or HTML body, like a CDN error page.
ResponseBody textResponse(int statusCode, String body) {
  return ResponseBody.fromString(
    body,
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['text/html'],
    },
  );
}

/// The backend's success envelope.
Map<String, Object?> successEnvelope(Object? data, {Object? meta}) {
  return {'success': true, 'data': data, 'meta': meta};
}

/// The backend's failure envelope.
Map<String, Object?> errorEnvelope(
  String code,
  String message, {
  Map<String, Object?>? details,
}) {
  return {
    'success': false,
    'error': {'code': code, 'message': message, 'details': details},
  };
}
