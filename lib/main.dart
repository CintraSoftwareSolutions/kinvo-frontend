import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/core/network/api_retry_policy.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/push/push_config.dart';
import 'src/features/calls/presentation/incoming_call_notification.dart';

void main() {
  // Registered before anything else runs, because Android calls it on a phone
  // whose app is closed — that is how an incoming call rings a phone in a
  // pocket. It does nothing in a build with no Firebase settings.
  if (PushConfig.fromEnvironment() != null) {
    WidgetsFlutterBinding.ensureInitialized();
    FirebaseMessaging.onBackgroundMessage(handleBackgroundPush);
  }

  _registerFontLicence();

  runApp(const ProviderScope(retry: apiRetryPolicy, child: KinvoApp()));
}

/// Tells Flutter's licence page about the bundled font.
///
/// Licences that come with a package are found on their own; a font that is
/// simply an asset has nothing for Flutter to read, so it has to be handed
/// over. Inter is under the SIL Open Font License, which asks for exactly
/// this.
void _registerFontLicence() {
  LicenseRegistry.addLicense(() async* {
    final licence = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const [AppTheme.fontFamily], licence);
  });
}
