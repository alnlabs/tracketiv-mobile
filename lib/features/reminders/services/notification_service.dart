import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  void Function(String goalId)? _onReminderTap;

  void configureReminderNavigation(void Function(String goalId) handler) {
    _onReminderTap = handler;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.startsWith('goal:')) {
          _onReminderTap?.call(payload.substring(5));
        }
      },
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  String _goalPayload(String goalId) => 'goal:$goalId';

  Future<void> scheduleCadenceReminder({
    required int id,
    required String goalId,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required String cadence,
    int? intervalDays,
    required List<int> daysOfWeek,
    required DateTime anchorDate,
  }) async {
    await cancel(id);

    switch (cadence) {
      case 'monthly':
        await _scheduleMonthly(
          id: id,
          goalId: goalId,
          title: title,
          body: body,
          hour: hour,
          minute: minute,
          dayOfMonth: anchorDate.day,
        );
      case 'custom':
        await _scheduleInterval(
          id: id,
          goalId: goalId,
          title: title,
          body: body,
          hour: hour,
          minute: minute,
          intervalDays: intervalDays ?? 1,
        );
      case 'weekly':
        await scheduleDailyReminder(
          id: id,
          goalId: goalId,
          title: title,
          body: body,
          hour: hour,
          minute: minute,
          daysOfWeek: daysOfWeek.isEmpty ? [anchorDate.weekday] : daysOfWeek,
        );
      case 'daily':
      default:
        await scheduleDailyReminder(
          id: id,
          goalId: goalId,
          title: title,
          body: body,
          hour: hour,
          minute: minute,
          daysOfWeek: daysOfWeek.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : daysOfWeek,
        );
    }
  }

  Future<void> scheduleDailyReminder({
    required int id,
    required String goalId,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required List<int> daysOfWeek,
  }) async {
    await cancel(id);

    for (final day in daysOfWeek) {
      await _plugin.zonedSchedule(
        id * 10 + day,
        title,
        body,
        _nextInstanceOfDayAndTime(day, hour, minute),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'tracketiv_reminders',
            'Goal Reminders',
            channelDescription: 'Reminders to log your goals',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: _goalPayload(goalId),
      );
    }
  }

  Future<void> _scheduleMonthly({
    required int id,
    required String goalId,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required int dayOfMonth,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      dayOfMonth.clamp(1, 28),
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month + 1,
        dayOfMonth.clamp(1, 28),
        hour,
        minute,
      );
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'tracketiv_reminders',
          'Goal Reminders',
          channelDescription: 'Reminders to log your goals',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      payload: _goalPayload(goalId),
    );
  }

  Future<void> _scheduleInterval({
    required int id,
    required String goalId,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required int intervalDays,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    scheduled = scheduled.add(Duration(days: intervalDays));

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'tracketiv_reminders',
          'Goal Reminders',
          channelDescription: 'Reminders to log your goals',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: _goalPayload(goalId),
    );
  }

  tz.TZDateTime _nextInstanceOfDayAndTime(int dayOfWeek, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    while (scheduled.weekday != dayOfWeek) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }
    return scheduled;
  }

  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
    for (var day = 1; day <= 7; day++) {
      await _plugin.cancel(id * 10 + day);
    }
  }

  Future<void> showInstant({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'tracketiv_activity',
          'Activity',
          channelDescription: 'Invites, reactions, and comments',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
