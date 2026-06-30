class FeedbackItem {
  const FeedbackItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.message,
    this.contactEmail,
    required this.createdAt,
    this.authorName,
    this.authorUsername,
    this.deletedAt,
  });

  final String id;
  final String userId;
  final String type;
  final String message;
  final String? contactEmail;
  final DateTime createdAt;
  final String? authorName;
  final String? authorUsername;
  final DateTime? deletedAt;

  String get authorLabel =>
      authorName ?? (authorUsername != null ? '@$authorUsername' : 'User');

  bool get isDeleted => deletedAt != null;

  String get typeLabel {
    switch (type) {
      case 'suggestion':
        return 'Suggestion';
      case 'improvement':
        return 'Improvement';
      case 'issue':
        return 'Issue';
      default:
        return type;
    }
  }

  factory FeedbackItem.fromJson(Map<String, dynamic> json) {
    return FeedbackItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      message: json['message'] as String,
      contactEmail: json['contact_email'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      authorName: json['author_name'] as String?,
      authorUsername: json['author_username'] as String?,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
    );
  }
}
