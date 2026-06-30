import '../utils/cadence_utils.dart';

class UserGoal {
  const UserGoal({
    required this.id,
    this.templateId,
    required this.ownerId,
    required this.title,
    this.description,
    required this.mode,
    required this.cadence,
    this.cadenceIntervalDays,
    required this.metricType,
    this.metricUnit,
    this.targetValue,
    this.startValue,
    this.targetDate,
    required this.status,
    required this.createdAt,
    this.groupId,
    this.groupName,
  });

  final String id;
  final String? templateId;
  final String ownerId;
  final String title;
  final String? description;
  final String mode;
  final String cadence;
  final int? cadenceIntervalDays;
  final String metricType;
  final String? metricUnit;
  final double? targetValue;
  final double? startValue;
  final DateTime? targetDate;
  final String status;
  final DateTime createdAt;
  final String? groupId;
  final String? groupName;

  bool get isGroup => mode == 'group' || groupId != null;
  bool get isActive => status == 'active';
  String get cadenceLabel => CadenceUtils.label(cadence, intervalDays: cadenceIntervalDays);

  factory UserGoal.fromJson(Map<String, dynamic> json) {
    return UserGoal(
      id: json['id'] as String,
      templateId: json['template_id'] as String?,
      ownerId: json['owner_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      mode: json['mode'] as String,
      cadence: json['cadence'] as String,
      cadenceIntervalDays: (json['cadence_interval_days'] as num?)?.toInt(),
      metricType: json['metric_type'] as String,
      metricUnit: json['metric_unit'] as String?,
      targetValue: (json['target_value'] as num?)?.toDouble(),
      startValue: (json['start_value'] as num?)?.toDouble(),
      targetDate: json['target_date'] != null
          ? DateTime.parse(json['target_date'] as String)
          : null,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      groupId: json['group_id'] as String?,
      groupName: (json['groups'] as Map<String, dynamic>?)?['name'] as String?,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'template_id': templateId,
        'owner_id': ownerId,
        'title': title,
        'description': description,
        'mode': mode,
        'cadence': cadence,
        if (cadenceIntervalDays != null) 'cadence_interval_days': cadenceIntervalDays,
        'metric_type': metricType,
        'metric_unit': metricUnit,
        'target_value': targetValue,
        'start_value': startValue,
        'target_date': targetDate?.toIso8601String().split('T').first,
        'status': status,
        if (groupId != null) 'group_id': groupId,
      };

  Map<String, dynamic> toUpdateJson() => {
        'title': title,
        'description': description ?? '',
        'cadence': cadence,
        if (cadenceIntervalDays != null) 'cadence_interval_days': cadenceIntervalDays,
        'target_value': targetValue?.toString() ?? '',
        'start_value': startValue?.toString() ?? '',
        'target_date': targetDate != null
            ? targetDate!.toIso8601String().split('T').first
            : '',
        'status': status,
      };
}
