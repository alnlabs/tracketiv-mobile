class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    this.displayName,
    this.username,
    required this.isAdmin,
    required this.isSystemAdmin,
    this.deletedAt,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? username;
  final bool isAdmin;
  final bool isSystemAdmin;
  final DateTime? deletedAt;
  final DateTime createdAt;

  String get name => displayName ?? username ?? email;

  String? get handle => username != null ? '@$username' : null;

  bool get isDeleted => deletedAt != null;

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      username: json['username'] as String?,
      isAdmin: json['is_admin'] as bool? ?? false,
      isSystemAdmin: json['is_system_admin'] as bool? ?? false,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
