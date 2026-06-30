class GoalMembership {
  const GoalMembership({
    required this.id,
    required this.userGoalId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.profile,
  });

  final String id;
  final String userGoalId;
  final String userId;
  final String role;
  final DateTime joinedAt;
  final Map<String, dynamic>? profile;

  String? get displayName => profile?['display_name'] as String?;
  String? get username => profile?['username'] as String?;
  String get publicLabel => displayName ?? (username != null ? '@$username' : 'User');

  factory GoalMembership.fromJson(Map<String, dynamic> json) {
    return GoalMembership(
      id: json['id'] as String,
      userGoalId: json['user_goal_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      profile: json['profiles'] as Map<String, dynamic>?,
    );
  }
}
