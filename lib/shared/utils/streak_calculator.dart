import '../models/log.dart';

class StreakCalculator {
  static int calculate(List<LogEntry> logs) {
    if (logs.isEmpty) return 0;

    final dates = logs.map((l) => _dateOnly(l.logDate)).toSet().toList()
      ..sort((a, b) => b.compareTo(a));

    var streak = 0;
    var expected = _dateOnly(DateTime.now());

    for (final date in dates) {
      if (date == expected || (streak == 0 && date == expected.subtract(const Duration(days: 1)))) {
        if (streak == 0 && date == expected.subtract(const Duration(days: 1))) {
          expected = date;
        }
        streak++;
        expected = expected.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
