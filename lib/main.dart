import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'utils/app_diagnostics.dart';

void main() {
  runZonedGuarded<void>(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (FlutterErrorDetails details) {
        AppDiagnostics.instance.recordFlutterError(details);
        FlutterError.presentError(details);
      };

      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        AppDiagnostics.instance.recordError(error, stack);
        return false;
      };

      AppDiagnostics.instance.log('App started in ${kReleaseMode ? 'release' : kProfileMode ? 'profile' : 'debug'} mode');
      runApp(const TheEastApp());
    },
    (Object error, StackTrace stack) {
      AppDiagnostics.instance.recordError(error, stack);
    },
  );
}
