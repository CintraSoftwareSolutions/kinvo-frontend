import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';
import '../network/api_client_provider.dart';
import '../network/api_envelope.dart';
import '../network/dio_exception_mapper.dart';
import '../network/network_providers.dart';

/// What an upload is for. The server decides where it's stored and which
/// files are allowed from this.
enum UploadPurpose {
  profilePhoto('profile_photo'),

  /// A photo sent in a conversation.
  chatImage('chat_image'),

  /// A screenshot or photo attached to a report.
  reportEvidence('report_evidence');

  const UploadPurpose(this.wireValue);

  final String wireValue;
}

/// Where and how to send an upload's bytes, from `POST /media/uploads`.
@immutable
final class UploadTicket {
  const UploadTicket({
    required this.uploadId,
    required this.url,
    required this.headers,
  });

  factory UploadTicket.fromJson(JsonMap json) {
    if (json case {
      'upload_id': final String uploadId,
      'url': final String rawUrl,
      'headers': final JsonMap rawHeaders,
    } when uploadId.isNotEmpty) {
      final url = Uri.tryParse(rawUrl);
      final headers = {
        for (final MapEntry(:key, :value) in rawHeaders.entries)
          if (value is String) key: value,
      };
      if (url != null &&
          url.host.isNotEmpty &&
          AppConfig.isSecureOrLocal(url) &&
          headers.length == rawHeaders.length) {
        return UploadTicket(uploadId: uploadId, url: url, headers: headers);
      }
    }
    throw const FormatException(
      'Expected an upload_id, a secure url and headers with string values.',
    );
  }

  final String uploadId;

  /// A presigned storage URL. It expires, and only accepts the bytes it was
  /// issued for.
  final Uri url;

  /// Headers the upload must send unchanged, or storage refuses it.
  final Map<String, String> headers;
}

/// Uploads files the way the backend requires: the bytes go straight to
/// storage, then the server checks what arrived before anything can use it.
final class MediaUploader {
  MediaUploader({required ApiClient api, required Dio storage})
    : _api = api,
      _storage = storage;

  final ApiClient _api;
  final Dio _storage;

  /// Uploads [bytes] and returns the id of the finished upload, ready to be
  /// attached to whatever it's for.
  ///
  /// Failures are `ApiException`s. A failed upload leaves nothing usable
  /// behind, so trying again starts from the beginning.
  Future<String> upload({
    required UploadPurpose purpose,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final ticket = await _api.post(
      '/media/uploads',
      body: {
        'purpose': purpose.wireValue,
        'mime_type': mimeType,
        'size_bytes': bytes.length,
      },
      decode: UploadTicket.fromJson,
    );

    await _sendBytes(ticket, bytes);

    await _api.post(
      '/media/uploads/${Uri.encodeComponent(ticket.uploadId)}/complete',
      decode: ApiClient.ignoreData,
    );
    return ticket.uploadId;
  }

  Future<void> _sendBytes(UploadTicket ticket, Uint8List bytes) async {
    try {
      await _storage.putUri<Object?>(
        ticket.url,
        data: bytes,
        options: Options(
          headers: ticket.headers,
          responseType: ResponseType.plain,
        ),
      );
    } on DioException catch (error, stackTrace) {
      Error.throwWithStackTrace(mapDioException(error), stackTrace);
    }
  }
}

/// Dio for sending bytes to presigned storage URLs.
///
/// Deliberately bare: no base URL, session, device headers or logging. A
/// presigned URL carries its own authorisation, storage refuses a request that
/// also sends the session's, and the URL's query string is a credential that
/// must never reach a log.
final storageDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      // A photo over a slow mobile connection.
      sendTimeout: const Duration(minutes: 2),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  if (ref.watch(httpClientAdapterProvider) case final adapter?) {
    dio.httpClientAdapter = adapter;
  }
  ref.onDispose(dio.close);
  return dio;
});

final mediaUploaderProvider = Provider<MediaUploader>(
  (ref) => MediaUploader(
    api: ref.watch(apiClientProvider),
    storage: ref.watch(storageDioProvider),
  ),
);
