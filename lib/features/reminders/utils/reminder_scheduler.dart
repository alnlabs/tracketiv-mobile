import '../../../shared/models/reminder.dart';
import '../../../shared/utils/notification_ids.dart';
import '../services/notification_service.dart';

/// Schedules per-goal local log reminders based on cadence + user settings.
class ReminderScheduler {
  ReminderScheduler._();

  static int idForGoal(String goalId) => NotificationIds.forGoal(goalId);

  static Future<void> apply(Reminder reminder) async {
    final id = idForGoal(reminder.userGoalId);
    if (!reminder.enabled) {
      await NotificationService.instance.cancel(id);
      return;
    }

    final parts = reminder.timeOfDay.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final title = reminder.goalTitle ?? 'your goal';

    await NotificationService.instance.scheduleCadenceReminder(
      id: id,
      goalId: reminder.userGoalId,
      title: 'Time to log!',
      body: 'Log progress for $title',
      hour: hour,
      minute: minute,
      cadence: reminder.goalCadence ?? 'daily',
      intervalDays: reminder.goalCadenceIntervalDays,
      daysOfWeek: reminder.daysOfWeek,
      anchorDate: reminder.goalCreatedAt ?? DateTime.now(),
    );
  }

  static Future<void> syncAll(List<Reminder> reminders) async {
    for (final reminder in reminders) {
      await apply(reminder);
    }
  }
}
