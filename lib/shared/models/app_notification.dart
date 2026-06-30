enum NotificationType {
  groupInvite,
  goalInvite,
  reaction,
  comment,
  groupPost,
  groupReaction,
  groupComment,
  friendRequest,
  friendAccepted;

  static NotificationType fromString(String value) {
    switch (value) {
      case 'group_invite':
        return NotificationType.groupInvite;
      case 'goal_invite':
        return NotificationType.goalInvite;
      case 'reaction':
        return NotificationType.reaction;
      case 'comment':
        return NotificationType.comment;
      case 'group_post':
        return NotificationType.groupPost;
      case 'group_reaction':
        return NotificationType.groupReaction;
      case 'group_comment':
        return NotificationType.groupComment;
      case 'friend_request':
        return NotificationType.friendRequest;
      case 'friend_accepted':
        return NotificationType.friendAccepted;
      default:
        return NotificationType.comment;
    }
  }

  String get value {
    switch (this) {
      case NotificationType.groupInvite:
        return 'group_invite';
      case NotificationType.goalInvite:
        return 'goal_invite';
      case NotificationType.reaction:
        return 'reaction';
      case NotificationType.comment:
        return 'comment';
      case NotificationType.groupPost:
        return 'group_post';
      case NotificationType.groupReaction:
        return 'group_reaction';
      case NotificationType.groupComment:
        return 'group_comment';
      case NotificationType.friendRequest:
        return 'friend_request';
      case NotificationType.friendAccepted:
        return 'friend_accepted';
    }
  }

  bool get isFriendActivity =>
      this == friendRequest || this == friendAccepted;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  String? get goalId => data['goal_id'] as String?;
  String? get logId => data['log_id'] as String?;
  String? get groupId => data['group_id'] as String?;
  String? get inviteId => data['invite_id'] as String?;
  String? get requestId => data['request_id'] as String?;
  String? get actorId => data['actor_id'] as String?;
  String? get emojiType => data['emoji_type'] as String?;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: NotificationType.fromString(json['type'] as String),
      title: json['title'] as String,
      body: json['body'] as String,
      data: rawData is Map<String, dynamic>
          ? rawData
          : Map<String, dynamic>.from(rawData as Map? ?? {}),
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
