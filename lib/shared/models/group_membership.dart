class GroupMembership {
  const GroupMembership({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.profile,
  });

  final String id;
  final String groupId;
  final String userId;
  final String role;
  final DateTime joinedAt;
  final Map<String, dynamic>? profile;

  String? get displayName => profile?['display_name'] as String?;
  String? get username => profile?['username'] as String?;
  String get publicLabel => displayName ?? (username != null ? '@$username' : 'User');

  factory GroupMembership.fromJson(Map<String, dynamic> json) {
    return GroupMembership(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      profile: json['profiles'] as Map<String, dynamic>?,
    );
  }
}
