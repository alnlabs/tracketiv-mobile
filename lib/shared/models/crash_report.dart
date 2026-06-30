class CrashReport {
  const CrashReport({
    required this.id,
    this.userId,
    required this.message,
    this.stackTrace,
    required this.errorType,
    this.platform,
    this.appVersion,
    this.route,
    required this.isAdminMode,
    required this.createdAt,
    this.userEmail,
    this.userName,
  });

  final String id;
  final String? userId;
  final String message;
  final String? stackTrace;
  final String errorType;
  final String? platform;
  final String? appVersion;
  final String? route;
  final bool isAdminMode;
  final DateTime createdAt;
  final String? userEmail;
  final String? userName;

  String get sourceLabel => isAdminMode ? 'Admin' : 'User app';

  factory CrashReport.fromJson(Map<String, dynamic> json) {
    return CrashReport(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      message: json['message'] as String,
      stackTrace: json['stack_trace'] as String?,
      errorType: json['error_type'] as String,
      platform: json['platform'] as String?,
      appVersion: json['app_version'] as String?,
      route: json['route'] as String?,
      isAdminMode: json['is_admin_mode'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      userEmail: json['user_email'] as String?,
      userName: json['user_name'] as String?,
    );
  }
}
