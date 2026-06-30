class Reminder {
  const Reminder({
    required this.id,
    required this.userGoalId,
    required this.userId,
    required this.timeOfDay,
    required this.daysOfWeek,
    required this.enabled,
    this.lastSentAt,
    this.goalTitle,
    this.goalCadence,
    this.goalCadenceIntervalDays,
    this.goalCreatedAt,
  });

  final String id;
  final String userGoalId;
  final String userId;
  final String timeOfDay;
  final List<int> daysOfWeek;
  final bool enabled;
  final DateTime? lastSentAt;
  final String? goalTitle;
  final String? goalCadence;
  final int? goalCadenceIntervalDays;
  final DateTime? goalCreatedAt;

  factory Reminder.fromJson(Map<String, dynamic> json) {
    final days = json['days_of_week'];
    final goal = json['user_goals'];
    final goalMap = goal is Map<String, dynamic> ? goal : null;

    return Reminder(
      id: json['id'] as String,
      userGoalId: json['user_goal_id'] as String,
      userId: json['user_id'] as String,
      timeOfDay: json['time_of_day'] as String,
      daysOfWeek: days is List ? days.cast<int>() : [1, 2, 3, 4, 5, 6, 7],
      enabled: json['enabled'] as bool? ?? true,
      lastSentAt: json['last_sent_at'] != null
          ? DateTime.parse(json['last_sent_at'] as String)
          : null,
      goalTitle: goalMap?['title'] as String?,
      goalCadence: goalMap?['cadence'] as String?,
      goalCadenceIntervalDays: (goalMap?['cadence_interval_days'] as num?)?.toInt(),
      goalCreatedAt: goalMap?['created_at'] != null
          ? DateTime.parse(goalMap!['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_goal_id': userGoalId,
        'user_id': userId,
        'time_of_day': timeOfDay,
        'days_of_week': daysOfWeek,
        'enabled': enabled,
      };
}
