// Firebase configuration for TapTalk (project: taptalk-2d809).
// Android: android/app/google-services.json
// iOS: ios/Runner/GoogleService-Info.plist + values below
// Desktop (Windows/Linux/macOS) uses the same project credentials.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return desktop;
      case TargetPlatform.windows:
        return desktop;
      case TargetPlatform.linux:
        return desktop;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC78hfq5hRC1f9i3jUpL3nHYCz5ONnRFx0',
    appId: '1:1001855891765:android:79d4a1d5a27fc152a5747c',
    messagingSenderId: '1001855891765',
    projectId: 'taptalk-2d809',
    storageBucket: 'taptalk-2d809.firebasestorage.app',
  );

  /// Desktop platforms use the same registered Firebase app credentials.
  static const FirebaseOptions desktop = FirebaseOptions(
    apiKey: 'AIzaSyC78hfq5hRC1f9i3jUpL3nHYCz5ONnRFx0',
    appId: '1:1001855891765:android:79d4a1d5a27fc152a5747c',
    messagingSenderId: '1001855891765',
    projectId: 'taptalk-2d809',
    authDomain: 'taptalk-2d809.firebaseapp.com',
    storageBucket: 'taptalk-2d809.firebasestorage.app',
  );

  static const FirebaseOptions web = desktop;

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC78hfq5hRC1f9i3jUpL3nHYCz5ONnRFx0',
    appId: '1:1001855891765:ios:79d4a1d5a27fc152a5747c',
    messagingSenderId: '1001855891765',
    projectId: 'taptalk-2d809',
    storageBucket: 'taptalk-2d809.firebasestorage.app',
    iosBundleId: 'com.example.flutterApplication1',
  );
}
