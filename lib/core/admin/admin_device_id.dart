import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Stable identifier for this install, used to recognize trusted admin devices.
class AdminDeviceId {
  AdminDeviceId._();

  static const _key = 'tracketiv-admin-device-id';

  static Future<String> get() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    if (existing != null && existing.isNotEmpty) return existing;

    final id = _generateId();
    await prefs.setString(_key, id);
    return id;
  }

  static String _generateId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
