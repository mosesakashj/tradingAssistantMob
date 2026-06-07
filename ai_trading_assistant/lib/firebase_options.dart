// ⚠️  ACTION REQUIRED: Configure Firebase before running the app.
//
// Steps:
//  1. Go to https://console.firebase.google.com/
//  2. Create a new project (e.g. "ai-trading-coach")
//  3. Add an Android app with package ID: com.aitrading.ai_trading_assistant
//  4. Download google-services.json → place in android/app/
//  5. Install FlutterFire CLI:
//       dart pub global activate flutterfire_cli
//  6. Run from this project root:
//       flutterfire configure
//     This auto-generates the correct values below.
//
// OR manually replace the placeholder strings below with values from:
//   Firebase Console → Project Settings → Your apps → SDK setup and configuration

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Web platform not configured. Run: flutterfire configure',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions not configured for ${defaultTargetPlatform.name}. '
          'Run: flutterfire configure',
        );
    }
  }

  // ⚠️  Replace ALL placeholder values below with your actual Firebase project values.
  // Found at: Firebase Console → Project Settings → General → Your apps
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_WITH_YOUR_ANDROID_API_KEY',
    appId: 'REPLACE_WITH_YOUR_ANDROID_APP_ID',
    messagingSenderId: 'REPLACE_WITH_YOUR_SENDER_ID',
    projectId: 'REPLACE_WITH_YOUR_PROJECT_ID',
    storageBucket: 'REPLACE_WITH_YOUR_PROJECT_ID.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_YOUR_IOS_API_KEY',
    appId: 'REPLACE_WITH_YOUR_IOS_APP_ID',
    messagingSenderId: 'REPLACE_WITH_YOUR_SENDER_ID',
    projectId: 'REPLACE_WITH_YOUR_PROJECT_ID',
    storageBucket: 'REPLACE_WITH_YOUR_PROJECT_ID.firebasestorage.app',
    iosClientId: 'REPLACE_WITH_YOUR_IOS_CLIENT_ID',
    iosBundleId: 'com.aitrading.aiTradingAssistant',
  );
}
