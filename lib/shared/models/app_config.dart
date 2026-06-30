class AppConfig {
  const AppConfig({
    required this.settings,
    this.systemAdminEmail,
  });

  final Map<String, String> settings;
  final String? systemAdminEmail;

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final rawSettings = json['settings'];
    final settings = <String, String>{};
    if (rawSettings is Map) {
      rawSettings.forEach((key, value) {
        settings[key.toString()] = value?.toString() ?? '';
      });
    }

    return AppConfig(
      settings: settings,
      systemAdminEmail: json['system_admin_email'] as String?,
    );
  }
}
