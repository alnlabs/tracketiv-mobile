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

  String? get authorName =>
      authorProfile?['display_name'] as String? ??
      (authorProfile?['username'] != null ? '@${authorProfile!['username']}' : null);

  /// Calendar date in local timezone for DB `log_date` (date column).
  static String formatLogDate(DateTime date) {
    final local = date.toLocal();
    final y = local.year;
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String get logDateString => formatLogDate(logDate);

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
        'log_date': logDateString,
        'value': value,
        'note': note,
      };

  Map<String, dynamic> toUpdateJson() => {
        'value': value,
        'note': note,
      };
}
