import 'package:kinvo/src/core/ringtone/ringtone.dart';

/// A phone with a ringtone chooser, whose answers the test decides.
final class FakeRingtones implements Ringtones {
  FakeRingtones({this.chooses, this.knownTitles = const {}});

  /// What the chooser returns, or null for "the user backed out".
  ChosenRingtone? chooses;

  /// Sounds this phone still has, by address.
  Map<String, String> knownTitles;

  bool playing = false;
  String? playedUri;
  int stops = 0;

  @override
  bool get canChoose => true;

  @override
  Future<ChosenRingtone?> choose({String? current}) async => chooses;

  @override
  Future<String?> titleOf(String uri) async => knownTitles[uri];

  @override
  Future<String?> defaultTitle() async => 'Phone default';

  @override
  Future<void> play({String? uri, bool vibrate = true}) async {
    playing = true;
    playedUri = uri;
  }

  @override
  Future<void> stop() async {
    playing = false;
    stops += 1;
  }
}
