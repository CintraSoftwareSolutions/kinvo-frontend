import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

/// Opens things outside the app: a web page in the browser, a new email in
/// the mail app.
///
/// An interface so no screen imports the plugin, and tests can see what
/// would have opened without leaving the test.
abstract interface class ExternalLinks {
  /// Opens [page] in the browser. False when nothing on the phone could.
  Future<bool> openPage(Uri page);

  /// Starts an email to [to] in the mail app, with [subject] filled in.
  /// False when the phone has no mail app.
  Future<bool> writeEmail({required String to, String? subject});
}

/// [ExternalLinks] on the phone, through `url_launcher`.
final class DeviceExternalLinks implements ExternalLinks {
  const DeviceExternalLinks();

  @override
  Future<bool> openPage(Uri page) => _open(page);

  @override
  Future<bool> writeEmail({required String to, String? subject}) {
    return _open(
      Uri(
        scheme: 'mailto',
        path: to,
        // Encoded by hand: `queryParameters` turns spaces into "+", which
        // mail apps show as they are.
        query: subject == null
            ? null
            : 'subject=${Uri.encodeComponent(subject)}',
      ),
    );
  }

  static Future<bool> _open(Uri uri) async {
    try {
      return await launcher.launchUrl(
        uri,
        mode: launcher.LaunchMode.externalApplication,
      );
    } on PlatformException {
      return false;
    }
  }
}

final externalLinksProvider = Provider<ExternalLinks>(
  (ref) => const DeviceExternalLinks(),
);
