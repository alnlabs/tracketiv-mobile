import '../models/profile.dart';

abstract final class GreetingUtils {
  static String timeOfDay([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String? firstName(Profile? profile) {
    final displayName = profile?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName.split(RegExp(r'\s+')).first;
    }
    final username = profile?.username?.trim();
    if (username != null && username.isNotEmpty) return username;
    return null;
  }

  static String withName(Profile? profile, [DateTime? now]) {
    final name = firstName(profile);
    final greeting = timeOfDay(now);
    if (name == null) return greeting;
    return '$greeting, $name';
  }
}
