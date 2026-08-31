import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

abstract final class EastAppFirebaseOptions {
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => null,
    };
  }

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyDb08cs4kYoSLfvBWjkGeIE_pXWHzLvR8g',
    appId: '1:359686683344:android:52ab0f2da026826c2c3cd5',
    messagingSenderId: '359686683344',
    projectId: 'theeast-888',
    storageBucket: 'theeast-888.firebasestorage.app',
  );

  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyDqIVwq7zNeeoDscb5pvBjr9TSARDm9uzg',
    appId: '1:359686683344:ios:f2e0d3ef869ecea12c3cd5',
    messagingSenderId: '359686683344',
    projectId: 'theeast-888',
    storageBucket: 'theeast-888.firebasestorage.app',
    iosBundleId: 'com.jenssen.eastapp.test',
  );
}
