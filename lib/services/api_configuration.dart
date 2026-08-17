import 'package:flutter/foundation.dart';

class ApiConfiguration {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'EASTAPP_API_BASE_URL',
    defaultValue: '',
  );

  static String get _trimmedConfiguredBaseUrl => _configuredBaseUrl.trim();

  static bool get hasConfiguredBaseUrl =>
      _trimmedConfiguredBaseUrl.isNotEmpty;

  static String? get startupError {
    if (kReleaseMode && !hasConfiguredBaseUrl) {
      return 'This release build has no backend URL. Rebuild it with '
          '--dart-define=EASTAPP_API_BASE_URL=https://<railway-domain>.up.railway.app';
    }
    return null;
  }

  static String get baseUrl {
    final configured = _trimmedConfiguredBaseUrl;
    if (configured.isNotEmpty) {
      return configured.endsWith('/')
          ? configured.substring(0, configured.length - 1)
          : configured;
    }

    // Never throw during widget construction. In release mode the app shows
    // ApiConfiguration.startupError instead of leaving a blank native screen.
    if (kReleaseMode) {
      return 'https://eastapp.invalid';
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:8080';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'http://192.168.0.248:8080';
    }
    return 'http://127.0.0.1:8080';
  }
}
