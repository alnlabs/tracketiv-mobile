class CadenceUtils {
  static const values = ['daily', 'weekly', 'monthly', 'custom'];

  static String label(String cadence, {int? intervalDays}) {
    switch (cadence) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      case 'custom':
        if (intervalDays != null && intervalDays > 0) {
          return intervalDays == 1 ? 'Every day' : 'Every $intervalDays days';
        }
        return 'Custom';
      default:
        return cadence;
    }
  }

  static String hint(String cadence, {int? intervalDays}) {
    switch (cadence) {
      case 'daily':
        return 'Log progress every day';
      case 'weekly':
        return 'Log once per week';
      case 'monthly':
        return 'Log once per month';
      case 'custom':
        if (intervalDays != null && intervalDays > 0) {
          return 'Log every $intervalDays days';
        }
        return 'Set your own interval';
      default:
        return '';
    }
  }

  /// Default weekdays (ISO: Mon=1 … Sun=7) for reminder scheduling.
  static List<int> defaultReminderDays(
    String cadence, {
    required DateTime goalCreatedAt,
  }) {
    switch (cadence) {
      case 'weekly':
        return [goalCreatedAt.weekday];
      case 'monthly':
        return [goalCreatedAt.weekday];
      case 'daily':
      case 'custom':
      default:
        return [1, 2, 3, 4, 5, 6, 7];
    }
  }

  static String reminderScheduleHint(
    String cadence, {
    int? intervalDays,
    DateTime? goalCreatedAt,
  }) {
    switch (cadence) {
      case 'daily':
        return 'Daily goal — reminder on selected days at your chosen time.';
      case 'weekly':
        final day = goalCreatedAt != null ? _weekdayName(goalCreatedAt.weekday) : 'your goal day';
        return 'Weekly goal — defaults to $day; pick the day you want a nudge.';
      case 'monthly':
        final dom = goalCreatedAt?.day;
        return dom != null
            ? 'Monthly goal — reminder on day $dom of each month.'
            : 'Monthly goal — reminder on the same day each month.';
      case 'custom':
        if (intervalDays != null && intervalDays > 0) {
          return 'Every $intervalDays days — next reminder scheduled from today.';
        }
        return 'Custom interval — reminder repeats on your schedule.';
      default:
        return 'Reminder based on your goal cadence.';
    }
  }

  static bool showsDayPicker(String cadence) =>
      cadence == 'daily' || cadence == 'weekly';

  static String _weekdayName(int isoDay) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(isoDay - 1).clamp(0, 6)];
  }
}
