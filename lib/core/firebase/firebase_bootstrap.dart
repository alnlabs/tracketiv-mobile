import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static Future<bool> initialize() async {
    if (_initialized) return true;
    if (kIsWeb || !Env.isFirebaseConfigured) return false;

    try {
      await Firebase.initializeApp(options: _options);
      _initialized = true;
      return true;
    } catch (e) {
      debugPrint('Firebase init skipped: $e');
      return false;
    }
  }

  static FirebaseOptions get _options {
    if (!kIsWeb && Platform.isIOS) {
      return FirebaseOptions(
        apiKey: Env.firebaseApiKey,
        appId: Env.firebaseAppIdIos,
        messagingSenderId: Env.firebaseMessagingSenderId,
        projectId: Env.firebaseProjectId,
        iosBundleId: Env.firebaseIosBundleId,
      );
    }

    return FirebaseOptions(
      apiKey: Env.firebaseApiKey,
      appId: Env.firebaseAppIdAndroid,
      messagingSenderId: Env.firebaseMessagingSenderId,
      projectId: Env.firebaseProjectId,
    );
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await FirebaseBootstrap.initialize();
}
