class AdminDashboardStats {
  const AdminDashboardStats({
    required this.usersTotal,
    required this.usersDeleted,
    required this.templatesTotal,
    required this.templatesDeleted,
    required this.feedbackTotal,
    required this.feedbackOpen,
    required this.goalsTotal,
    required this.groupsTotal,
    required this.crashesTotal,
    required this.crashes24h,
  });

  final int usersTotal;
  final int usersDeleted;
  final int templatesTotal;
  final int templatesDeleted;
  final int feedbackTotal;
  final int feedbackOpen;
  final int goalsTotal;
  final int groupsTotal;
  final int crashesTotal;
  final int crashes24h;

  factory AdminDashboardStats.fromJson(Map<String, dynamic> json) {
    return AdminDashboardStats(
      usersTotal: json['users_total'] as int? ?? 0,
      usersDeleted: json['users_deleted'] as int? ?? 0,
      templatesTotal: json['templates_total'] as int? ?? 0,
      templatesDeleted: json['templates_deleted'] as int? ?? 0,
      feedbackTotal: json['feedback_total'] as int? ?? 0,
      feedbackOpen: json['feedback_open'] as int? ?? 0,
      goalsTotal: json['goals_total'] as int? ?? 0,
      groupsTotal: json['groups_total'] as int? ?? 0,
      crashesTotal: json['crashes_total'] as int? ?? 0,
      crashes24h: json['crashes_24h'] as int? ?? 0,
    );
  }
}
