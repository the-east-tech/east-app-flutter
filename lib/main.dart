import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'services/push_notification_service.dart';
import 'utils/app_diagnostics.dart';

void main() {
  runZonedGuarded<void>(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      PushNotificationService.registerBackgroundHandler();

      FlutterError.onError = (FlutterErrorDetails details) {
        AppDiagnostics.instance.recordFlutterError(details);
        FlutterError.presentError(details);
      };

      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        AppDiagnostics.instance.recordError(error, stack);
        return false;
      };

      runApp(const TheEastApp());
    },
    (Object error, StackTrace stack) {
      AppDiagnostics.instance.recordError(error, stack);
    },
  );
}
