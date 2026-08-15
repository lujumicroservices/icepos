// Firebase / FCM. Pasos:
// 1) Firebase Console → proyecto → añadir app Android (package com.luju.ice_pos).
// 2) Descargar google-services.json → ice_pos/android/app/google-services.json
// 3) Pegar aquí los valores de Firebase → Configuración del proyecto → Tu app Android.
//
// O ejecutar: dart pub global activate flutterfire_cli && flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('FCM no se usa en web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('FCM solo en Android/iOS.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDkxeLb2L5RfXZYILkKorM7nWfmTXCBr00',
    appId: '1:601257611890:android:71d4d68d147d3b9d4aa8eb',
    messagingSenderId: '601257611890',
    projectId: 'lujunieves-b3409',
    storageBucket: 'lujunieves-b3409.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_FIREBASE_API_KEY',
    appId: 'YOUR_FIREBASE_APP_ID',
    messagingSenderId: 'YOUR_FIREBASE_MESSAGING_SENDER_ID',
    projectId: 'YOUR_FIREBASE_PROJECT_ID',
    storageBucket: 'YOUR_FIREBASE_PROJECT_ID.appspot.com',
    iosBundleId: 'com.luju.icePos',
  );

  static bool get isConfigured {
    const o = android;
    return o.projectId.isNotEmpty &&
        !o.projectId.startsWith('YOUR_') &&
        o.apiKey.isNotEmpty &&
        !o.apiKey.startsWith('YOUR_');
  }
}
