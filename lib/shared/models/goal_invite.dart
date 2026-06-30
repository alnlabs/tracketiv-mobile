class GoalInvite {
  const GoalInvite({
    required this.id,
    required this.userGoalId,
    required this.invitedEmail,
    required this.invitedBy,
    required this.status,
    required this.createdAt,
    this.goalTitle,
    this.invitedByName,
  });

  final String id;
  final String userGoalId;
  final String invitedEmail;
  final String invitedBy;
  final String status;
  final DateTime createdAt;
  final String? goalTitle;
  final String? invitedByName;

  bool get isPending => status == 'pending';

  factory GoalInvite.fromJson(Map<String, dynamic> json) {
    return GoalInvite(
      id: json['id'] as String,
      userGoalId: json['user_goal_id'] as String,
      invitedEmail: json['invited_email'] as String? ?? '',
      invitedBy: json['invited_by'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      goalTitle: json['goal_title'] as String?,
      invitedByName: json['invited_by_name'] as String?,
    );
  }
}

class InviteResult {
  const InviteResult({required this.status, this.userId});

  final String status;
  final String? userId;

  bool get isAdded => status == 'added';
  bool get isInvited => status == 'invited';
  bool get isAlreadyMember => status == 'already_member';

  factory InviteResult.fromJson(Map<String, dynamic> json) {
    return InviteResult(
      status: json['status'] as String,
      userId: json['user_id'] as String?,
    );
  }

  String get message {
    switch (status) {
      case 'added':
        return 'Member added to the group';
      case 'invited':
        return 'Invite sent — they will join when they sign up';
      case 'already_member':
        return 'This user is already in the group';
      default:
        return status;
    }
  }
}
