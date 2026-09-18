import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import 'api_envelope.dart';
import 'api_exception.dart';
import 'api_headers.dart';
import 'cursor_page.dart';
import 'dio_exception_mapper.dart';

/// Builds a model from one JSON object in a response.
typedef JsonDecoder<T> = T Function(JsonMap json);

/// Typed access to the Kinvo REST API.
///
/// Every method unwraps the response envelope and reports every failure as an
/// [ApiException], so callers never handle Dio types, HTTP statuses or raw
/// error JSON. Paths are relative to the API base URL and start with `/`, for
/// example `/auth/me`.
final class ApiClient {
  const ApiClient(this._dio);

  final Dio _dio;

  /// A [JsonDecoder] for calls whose response data isn't needed.
  static void ignoreData(JsonMap _) {}

  Future<T> get<T>(
    String path, {
    required JsonDecoder<T> decode,
    Map<String, Object?>? query,
    CancelToken? cancelToken,
  }) {
    return _send(
      method: 'GET',
      path: path,
      query: query,
      cancelToken: cancelToken,
      read: (body) => decode(ApiEnvelope.readData(body)),
    );
  }

  /// Fetches one page of a cursor-paginated list.
  ///
  /// Pass the previous page's [CursorPage.nextCursor] as [cursor] to continue
  /// where it ended.
  Future<CursorPage<T>> getPage<T>(
    String path, {
    required JsonDecoder<T> decodeItem,
    String? cursor,
    int? limit,
    Map<String, Object?>? query,
    CancelToken? cancelToken,
  }) {
    return _send(
      method: 'GET',
      path: path,
      query: {...?query, 'cursor': cursor, 'limit': limit},
      cancelToken: cancelToken,
      read: (body) {
        final list = ApiEnvelope.readList(body);
        return CursorPage(
          items: [for (final item in list.items) decodeItem(_asObject(item))],
          nextCursor: list.nextCursor,
          hasMore: list.hasMore,
          limit: list.limit,
        );
      },
    );
  }

  Future<T> post<T>(
    String path, {
    required JsonDecoder<T> decode,
    Object? body,
    CancelToken? cancelToken,
  }) {
    return _sendWithBody('POST', path, decode, body, cancelToken);
  }

  Future<T> put<T>(
    String path, {
    required JsonDecoder<T> decode,
    Object? body,
    CancelToken? cancelToken,
  }) {
    return _sendWithBody('PUT', path, decode, body, cancelToken);
  }

  Future<T> patch<T>(
    String path, {
    required JsonDecoder<T> decode,
    Object? body,
    CancelToken? cancelToken,
  }) {
    return _sendWithBody('PATCH', path, decode, body, cancelToken);
  }

  Future<T> delete<T>(
    String path, {
    required JsonDecoder<T> decode,
    Object? body,
    CancelToken? cancelToken,
  }) {
    return _sendWithBody('DELETE', path, decode, body, cancelToken);
  }

  Future<T> _sendWithBody<T>(
    String method,
    String path,
    JsonDecoder<T> decode,
    Object? body,
    CancelToken? cancelToken,
  ) {
    return _send(
      method: method,
      path: path,
      body: body,
      cancelToken: cancelToken,
      read: (responseBody) => decode(ApiEnvelope.readData(responseBody)),
    );
  }

  Future<R> _send<R>({
    required String method,
    required String path,
    required R Function(Object? body) read,
    Object? body,
    Map<String, Object?>? query,
    CancelToken? cancelToken,
  }) async {
    assert(path.startsWith('/'), 'API paths must start with "/": "$path".');

    final Response<Object?> response;
    try {
      response = await _dio.request<Object?>(
        path,
        data: body,
        queryParameters: _withoutNullValues(query),
        cancelToken: cancelToken,
        options: Options(method: method),
      );
    } on DioException catch (error, stackTrace) {
      Error.throwWithStackTrace(mapDioException(error), stackTrace);
    }

    try {
      return read(response.data);
    } on Object catch (error, stackTrace) {
      // A body that breaks the contract becomes a failure callers already
      // handle, instead of a TypeError thrown from deep inside a screen.
      final exception = UnexpectedResponseException(
        reason: 'Could not read the response to $method $path.',
        statusCode: response.statusCode,
        requestId: response.headers.value(ApiHeaders.requestId),
        cause: error,
      );
      developer.log(
        exception.reason,
        name: 'kinvo.api',
        error: error,
        stackTrace: stackTrace,
      );
      Error.throwWithStackTrace(exception, stackTrace);
    }
  }

  /// Optional parameters are passed as `null`; the backend expects them absent.
  static Map<String, Object>? _withoutNullValues(Map<String, Object?>? query) {
    if (query == null) return null;
    return {for (final MapEntry(:key, :value) in query.entries) key: ?value};
  }

  static JsonMap _asObject(Object? item) {
    if (item is JsonMap) return item;
    throw FormatException(
      'Expected every list item to be an object, but got ${item.runtimeType}.',
    );
  }
}
