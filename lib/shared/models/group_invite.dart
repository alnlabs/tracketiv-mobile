class GroupInvite {
  const GroupInvite({
    required this.id,
    required this.groupId,
    required this.invitedEmail,
    required this.invitedBy,
    required this.status,
    required this.createdAt,
    this.groupName,
    this.invitedByName,
  });

  final String id;
  final String groupId;
  final String invitedEmail;
  final String invitedBy;
  final String status;
  final DateTime createdAt;
  final String? groupName;
  final String? invitedByName;

  bool get isPending => status == 'pending';

  factory GroupInvite.fromJson(Map<String, dynamic> json) {
    return GroupInvite(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      invitedEmail: json['invited_email'] as String? ?? '',
      invitedBy: json['invited_by'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      groupName: json['group_name'] as String?,
      invitedByName: json['invited_by_name'] as String?,
    );
  }
}
