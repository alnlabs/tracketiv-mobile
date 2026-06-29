class LogComment {
  const LogComment({
    required this.id,
    required this.logId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.authorProfile,
  });

  final String id;
  final String logId;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final Map<String, dynamic>? authorProfile;

  String? get authorName => authorProfile?['display_name'] as String?;

  factory LogComment.fromJson(Map<String, dynamic> json) {
    return LogComment(
      id: json['id'] as String,
      logId: json['log_id'] as String,
      authorId: json['author_id'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      authorProfile: json['profiles'] as Map<String, dynamic>?,
    );
  }
}
