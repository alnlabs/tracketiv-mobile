class LogReaction {
  const LogReaction({
    required this.id,
    required this.logId,
    required this.userId,
    required this.emojiType,
    required this.createdAt,
  });

  final String id;
  final String logId;
  final String userId;
  final String emojiType;
  final DateTime createdAt;

  factory LogReaction.fromJson(Map<String, dynamic> json) {
    return LogReaction(
      id: json['id'] as String,
      logId: json['log_id'] as String,
      userId: json['user_id'] as String,
      emojiType: json['emoji_type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ReactionSummary {
  const ReactionSummary({
    required this.emojiType,
    required this.count,
    required this.reactedByMe,
  });

  final String emojiType;
  final int count;
  final bool reactedByMe;
}
