class LogEntry {
  const LogEntry({
    required this.id,
    required this.userGoalId,
    required this.authorId,
    required this.logDate,
    this.value,
    this.note,
    required this.createdAt,
    this.authorProfile,
  });

  final String id;
  final String userGoalId;
  final String authorId;
  final DateTime logDate;
  final double? value;
  final String? note;
  final DateTime createdAt;
  final Map<String, dynamic>? authorProfile;

  String? get authorName => authorProfile?['display_name'] as String?;

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      id: json['id'] as String,
      userGoalId: json['user_goal_id'] as String,
      authorId: json['author_id'] as String,
      logDate: DateTime.parse(json['log_date'] as String),
      value: (json['value'] as num?)?.toDouble(),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      authorProfile: json['profiles'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'user_goal_id': userGoalId,
        'author_id': authorId,
        'log_date': logDate.toIso8601String().split('T').first,
        'value': value,
        'note': note,
      };
}
