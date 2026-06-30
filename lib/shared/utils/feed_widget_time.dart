import 'package:flutter/material.dart';

String formatFeedWidgetTime(String raw) {
  final parts = raw.split(':');
  if (parts.length < 2) return raw;
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = int.tryParse(parts[1]) ?? 0;
  final isPm = hour >= 12;
  final h = hour % 12 == 0 ? 12 : hour % 12;
  final m = minute.toString().padLeft(2, '0');
  return '$h:$m ${isPm ? 'PM' : 'AM'}';
}

String feedWidgetTimeToStorage(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

TimeOfDay feedWidgetTimeFromStorage(String raw) {
  final parts = raw.split(':');
  return TimeOfDay(
    hour: int.tryParse(parts.elementAtOrNull(0) ?? '6') ?? 6,
    minute: int.tryParse(parts.elementAtOrNull(1) ?? '0') ?? 0,
  );
}

String deviceTimezoneName() => DateTime.now().timeZoneName;

String formatDailyQuoteSchedule(TimeOfDay time) {
  return 'Every day at ${formatFeedWidgetTime(feedWidgetTimeToStorage(time))}';
}

String formatDailyQuoteScheduleFromStorage(String raw) {
  return formatDailyQuoteSchedule(feedWidgetTimeFromStorage(raw));
}
