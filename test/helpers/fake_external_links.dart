import 'package:kinvo/src/core/links/external_links.dart';

/// [ExternalLinks] that opens nothing and remembers what it was asked to.
final class FakeExternalLinks implements ExternalLinks {
  /// Whether the phone has a browser and a mail app to hand things to.
  bool canOpenPages = true;
  bool canWriteEmail = true;

  /// Every page asked for, in order.
  final List<Uri> pages = [];

  /// Every email started, in order.
  final List<({String to, String? subject})> emails = [];

  @override
  Future<bool> openPage(Uri page) async {
    pages.add(page);
    return canOpenPages;
  }

  @override
  Future<bool> writeEmail({required String to, String? subject}) async {
    emails.add((to: to, subject: subject));
    return canWriteEmail;
  }
}
