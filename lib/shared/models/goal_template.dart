class GoalTemplate {
  const GoalTemplate({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.metricType,
    this.metricUnit,
    required this.cadence,
    this.defaultTarget = const {},
    this.icon,
  });

  final String id;
  final String title;
  final String? description;
  final String category;
  final String metricType;
  final String? metricUnit;
  final String cadence;
  final Map<String, dynamic> defaultTarget;
  final String? icon;

  factory GoalTemplate.fromJson(Map<String, dynamic> json) {
    return GoalTemplate(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      metricType: json['metric_type'] as String,
      metricUnit: json['metric_unit'] as String?,
      cadence: json['cadence'] as String,
      defaultTarget: Map<String, dynamic>.from(json['default_target'] as Map? ?? {}),
      icon: json['icon'] as String?,
    );
  }

  Map<String, dynamic> toAdminJson() => {
        if (id.isNotEmpty) 'id': id,
        'title': title,
        'description': description ?? '',
        'category': category,
        'metric_type': metricType,
        'metric_unit': metricUnit ?? '',
        'cadence': cadence,
        'default_target': defaultTarget,
        'icon': icon ?? '',
      };
}
