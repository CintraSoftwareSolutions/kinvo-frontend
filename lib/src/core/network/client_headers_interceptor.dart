import 'dart:ui' show PlatformDispatcher;

import 'package:dio/dio.dart';

import '../device/client_info.dart';
import 'api_headers.dart';

/// Identifies the app on every request: device id, platform, version,
/// language, and the device's model and system for the device list.
///
/// The backend ties sessions and push tokens to the device id, so every
/// request from this installation must carry the same one.
final class ClientHeadersInterceptor extends Interceptor {
  ClientHeadersInterceptor(this._clientInfo, {String Function()? languageTag})
    : _languageTag = languageTag ?? _platformLanguageTag;

  final Future<ClientInfo> Function() _clientInfo;
  final String Function() _languageTag;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final info = await _clientInfo();
      options.headers[ApiHeaders.deviceId] = info.deviceId;
      options.headers[ApiHeaders.appVersion] = info.appVersion;
      if (info.platform case final platform?) {
        options.headers[ApiHeaders.platform] = platform.wireValue;
      }
      if (info.deviceModel case final model?) {
        options.headers[ApiHeaders.deviceModel] = model;
      }
      if (info.osVersion case final osVersion?) {
        options.headers[ApiHeaders.osVersion] = osVersion;
      }
      options.headers[ApiHeaders.acceptLanguage] ??= _languageTag();
      handler.next(options);
    } on Object catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  static String _platformLanguageTag() {
    return PlatformDispatcher.instance.locale.toLanguageTag();
  }
}
