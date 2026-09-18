import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/media/media_uploader.dart';
import 'package:kinvo/src/core/network/api_error_code.dart';
import 'package:kinvo/src/core/network/api_exception.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_kinvo_server.dart';
import '../../helpers/test_backend.dart';

void main() {
  late FakeKinvoServer server;
  late TestBackend backend;
  late MediaUploader uploader;
  final bytes = Uint8List.fromList(List.generate(1024, (i) => i % 256));

  setUp(() async {
    server = FakeKinvoServer();
    backend = TestBackend(respond: server.respond);
    await backend.tokenStore.write(liveSession());
    uploader = backend.createContainer().read(mediaUploaderProvider);
  });

  Future<String> upload({String mimeType = 'image/jpeg'}) {
    return uploader.upload(
      purpose: UploadPurpose.profilePhoto,
      bytes: bytes,
      mimeType: mimeType,
    );
  }

  RequestOptions storageRequest() {
    return backend.adapter.requests.singleWhere(
      (request) => request.uri.host == FakeKinvoServer.storageHost,
    );
  }

  test('sends the bytes to storage, then has the server check them', () async {
    final uploadId = await upload();

    expect(backend.adapter.requests.map((r) => '${r.method} ${r.uri.path}'), [
      'POST /api/v1/media/uploads',
      'PUT /$uploadId',
      'POST /api/v1/media/uploads/$uploadId/complete',
    ]);
    expect(backend.adapter.requests.first.data, {
      'purpose': 'profile_photo',
      'mime_type': 'image/jpeg',
      'size_bytes': 1024,
    });
    expect(server.storedUploads[uploadId], bytes);
  });

  test('gives storage the signed headers and none of the session', () async {
    await upload();

    final api = backend.adapter.requests.first;
    expect(api.headers['authorization'], 'Bearer access-1');
    expect(api.headers['x-device-id'], testDeviceId);

    final storage = storageRequest();
    expect(storage.uri.query, 'X-Amz-Signature=write');
    expect(storage.headers['content-type'], 'image/jpeg');
    expect(storage.headers['content-length'], '1024');
    // The presigned URL is the credential. Storage refuses a second one, and
    // the device id is none of its business.
    expect(storage.headers.containsKey('authorization'), isFalse);
    expect(storage.headers.containsKey('x-device-id'), isFalse);
  });

  test('reports a file the server refuses before anything is sent', () async {
    await expectLater(
      upload(mimeType: 'image/gif'),
      throwsA(
        isA<ApiErrorException>().having(
          (error) => error.code,
          'code',
          ApiErrorCode.unsupportedMediaType,
        ),
      ),
    );
    expect(backend.adapter.requests, hasLength(1));
  });

  test('reports storage refusing the upload, and completes nothing', () async {
    server.intercept = (options) async =>
        options.uri.host == FakeKinvoServer.storageHost
        ? textResponse(403, '<Error><Code>AccessDenied</Code></Error>')
        : null;

    await expectLater(
      upload(),
      throwsA(
        isA<UnexpectedResponseException>().having(
          (error) => error.statusCode,
          'statusCode',
          403,
        ),
      ),
    );
    expect(
      backend.adapter.requests.where((r) => r.uri.path.endsWith('/complete')),
      isEmpty,
    );
  });

  test('reports losing the connection while sending', () async {
    server.intercept = (options) async {
      if (options.uri.host == FakeKinvoServer.storageHost) {
        throw const SocketException('Connection reset');
      }
      return null;
    };

    await expectLater(upload(), throwsA(isA<NetworkException>()));
  });

  group('an upload ticket', () {
    Map<String, Object?> ticket({String url = 'https://s3.test/key?sig=1'}) {
      return {
        'upload_id': 'upload-1',
        'url': url,
        'headers': {'Content-Type': 'image/jpeg', 'Content-Length': '10'},
      };
    }

    test('is read with its signed headers', () {
      final read = UploadTicket.fromJson(ticket());

      expect(read.uploadId, 'upload-1');
      expect(read.url, Uri.parse('https://s3.test/key?sig=1'));
      expect(read.headers, {
        'Content-Type': 'image/jpeg',
        'Content-Length': '10',
      });
    });

    test('is refused when it would send the photo unencrypted', () {
      expect(
        () => UploadTicket.fromJson(ticket(url: 'http://s3.test/key')),
        throwsFormatException,
      );
    });

    test('may use plain http to local development storage', () {
      final read = UploadTicket.fromJson(
        ticket(url: 'http://localhost:9000/bucket/key?sig=1'),
      );

      expect(read.url.host, 'localhost');
    });
  });
}
