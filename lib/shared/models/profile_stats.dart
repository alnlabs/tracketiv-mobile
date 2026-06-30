class GoalProfileStat {
  const GoalProfileStat({
    required this.goalId,
    required this.goalTitle,
    required this.goalMode,
    required this.goalCadence,
    required this.goalStatus,
    this.groupName,
    required this.logCount,
    this.lastLogDate,
    this.lastLogAt,
  });

  final String goalId;
  final String goalTitle;
  final String goalMode;
  final String goalCadence;
  final String goalStatus;
  final String? groupName;
  final int logCount;
  final DateTime? lastLogDate;
  final DateTime? lastLogAt;

  bool get isGroup => goalMode == 'group' || groupName != null;
  bool get isActive => goalStatus == 'active';

  factory GoalProfileStat.fromJson(Map<String, dynamic> json) {
    return GoalProfileStat(
      goalId: json['goal_id'] as String,
      goalTitle: json['goal_title'] as String,
      goalMode: json['goal_mode'] as String? ?? 'solo',
      goalCadence: json['goal_cadence'] as String? ?? 'daily',
      goalStatus: json['goal_status'] as String? ?? 'active',
      groupName: json['group_name'] as String?,
      logCount: json['log_count'] as int? ?? 0,
      lastLogDate: json['last_log_date'] != null
          ? DateTime.parse(json['last_log_date'] as String)
          : null,
      lastLogAt: json['last_log_at'] != null
          ? DateTime.parse(json['last_log_at'] as String)
          : null,
    );
  }
}

class ProfileStats {
  const ProfileStats({
    required this.totalGoals,
    required this.activeGoals,
    required this.totalLogs,
    required this.logsThisWeek,
    required this.currentStreak,
    required this.totalGroups,
    required this.goals,
  });

  final int totalGoals;
  final int activeGoals;
  final int totalLogs;
  final int logsThisWeek;
  final int currentStreak;
  final int totalGroups;
  final List<GoalProfileStat> goals;

  factory ProfileStats.fromJson(Map<String, dynamic> json) {
    final goalsJson = json['goals'];
    final goals = goalsJson is List
        ? goalsJson
            .map((e) => GoalProfileStat.fromJson(e as Map<String, dynamic>))
            .toList()
        : <GoalProfileStat>[];

    return ProfileStats(
      totalGoals: json['total_goals'] as int? ?? 0,
      activeGoals: json['active_goals'] as int? ?? 0,
      totalLogs: json['total_logs'] as int? ?? 0,
      logsThisWeek: json['logs_this_week'] as int? ?? 0,
      currentStreak: json['current_streak'] as int? ?? 0,
      totalGroups: json['total_groups'] as int? ?? 0,
      goals: goals,
    );
  }
}
