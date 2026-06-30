import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('your-project');

  static String get firebaseApiKey => dotenv.env['FIREBASE_API_KEY'] ?? '';
  static String get firebaseAppIdAndroid => dotenv.env['FIREBASE_APP_ID_ANDROID'] ?? '';
  static String get firebaseAppIdIos => dotenv.env['FIREBASE_APP_ID_IOS'] ?? '';
  static String get firebaseMessagingSenderId =>
      dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '';
  static String get firebaseProjectId => dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
  static String get firebaseIosBundleId =>
      dotenv.env['FIREBASE_IOS_BUNDLE_ID'] ?? 'com.alnlabs.tracketiv';

  static bool get isFirebaseConfigured =>
      firebaseApiKey.isNotEmpty &&
      firebaseMessagingSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty &&
      (firebaseAppIdAndroid.isNotEmpty || firebaseAppIdIos.isNotEmpty);

  static bool get pushNotificationsEnabled => isFirebaseConfigured;

  /// Web uses the current origin; mobile uses a deep link.
  static String get passwordResetRedirect {
    if (kIsWeb) {
      return '${Uri.base.origin}/reset-password';
    }
    return 'io.supabase.tracketiv://reset-password';
  }
}
