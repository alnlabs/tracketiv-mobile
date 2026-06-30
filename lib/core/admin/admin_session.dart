import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the current auth session is being used for the admin console.
class AdminSession {
  AdminSession._();

  static const _activeKey = 'tracketiv-admin-mode-active';

  static Future<bool> isActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_activeKey) ?? false;
  }

  static Future<void> setActive(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    if (active) {
      await prefs.setBool(_activeKey, true);
    } else {
      await prefs.remove(_activeKey);
    }
  }
}
