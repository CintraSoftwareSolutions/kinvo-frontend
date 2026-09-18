import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/config/app_config.dart';

void main() {
  group('AppConfig.parseApiBaseUrl', () {
    test('accepts an https URL and removes trailing slashes', () {
      final uri = AppConfig.parseApiBaseUrl(
        ' https://api.example.com/api/v1// ',
      );

      expect(uri.toString(), 'https://api.example.com/api/v1');
    });

    test('allows plain http for local development hosts', () {
      final uri = AppConfig.parseApiBaseUrl('http://10.0.2.2:3000/api/v1');

      expect(uri.toString(), 'http://10.0.2.2:3000/api/v1');
    });

    test('explains how to supply the value when it is missing', () {
      expect(
        () => AppConfig.parseApiBaseUrl(''),
        throwsA(
          isA<AppConfigException>().having(
            (e) => e.message,
            'message',
            contains('--dart-define-from-file'),
          ),
        ),
      );
    });

    test('rejects plain http for remote hosts', () {
      expect(
        () => AppConfig.parseApiBaseUrl('http://api.example.com/api/v1'),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rejects relative URLs', () {
      expect(
        () => AppConfig.parseApiBaseUrl('/api/v1'),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rejects URLs with a query or fragment', () {
      expect(
        () => AppConfig.parseApiBaseUrl('https://api.example.com/api/v1?x=1'),
        throwsA(isA<AppConfigException>()),
      );
      expect(
        () => AppConfig.parseApiBaseUrl('https://api.example.com/api/v1#top'),
        throwsA(isA<AppConfigException>()),
      );
    });
  });
}
