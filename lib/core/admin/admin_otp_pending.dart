import 'package:shared_preferences/shared_preferences.dart';

/// Whether an admin signed in but still needs OTP verification on this device.
class AdminOtpPending {
  AdminOtpPending._();

  static const _key = 'tracketiv-admin-otp-pending';

  static Future<bool> isPending() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> setPending(bool pending) async {
    final prefs = await SharedPreferences.getInstance();
    if (pending) {
      await prefs.setBool(_key, true);
    } else {
      await prefs.remove(_key);
    }
  }
}
