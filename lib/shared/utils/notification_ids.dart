/// Local notification ids must fit in a signed 32-bit integer on Android/iOS.
abstract final class NotificationIds {
  NotificationIds._();

  /// Max base id when deriving per-day ids as `base * 10 + day` (day 1–7).
  static const int _maxGoalBase = 200000000;

  /// Stable base id for per-goal reminder scheduling.
  static int forGoal(String goalId) => goalId.hashCode.abs() % _maxGoalBase;

  /// Stable id for a one-off notification from an arbitrary string key.
  static int fromKey(String key) => key.hashCode & 0x7FFFFFFF;

  /// Coerce any int (e.g. epoch millis) into 32-bit notification range.
  static int clamp(int value) => value & 0x7FFFFFFF;
}
