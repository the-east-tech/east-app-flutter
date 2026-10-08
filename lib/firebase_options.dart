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
    apiKey: 'AIzaSyA9uoeMWLsarIqaFLCs6R0b0bX_Q-HuXcw',
    appId: '1:312564235088:android:8b54642c83af6f7e254a55',
    messagingSenderId: '312564235088',
    projectId: 'sequosal-flow',
    storageBucket: 'sequosal-flow.firebasestorage.app',
  );

  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyBCeHfIDqRtf0VHrvGImYb3ZfdcU4wfD-k',
    appId: '1:312564235088:ios:b8f7b5d0fc77ce40254a55',
    messagingSenderId: '312564235088',
    projectId: 'sequosal-flow',
    storageBucket: 'sequosal-flow.firebasestorage.app',
    iosBundleId: 'com.sequosal.flow',
  );
}
