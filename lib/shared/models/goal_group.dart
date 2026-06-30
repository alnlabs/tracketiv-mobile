class GoalGroup {
  const GoalGroup({
    required this.id,
    required this.name,
    this.description,
    required this.ownerId,
    required this.createdAt,
    this.goalCount,
  });

  final String id;
  final String name;
  final String? description;
  final String ownerId;
  final DateTime createdAt;
  final int? goalCount;

  factory GoalGroup.fromJson(Map<String, dynamic> json) {
    final goals = json['user_goals'];
    int? count;
    if (goals is List) {
      count = goals.length;
    } else if (goals is Map) {
      count = 1;
    } else {
      count = json['goal_count'] as int?;
    }

    return GoalGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      ownerId: json['owner_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      goalCount: count,
    );
  }
}
