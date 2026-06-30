class AdminTable {
  const AdminTable(this.key, this.label);

  final String key;
  final String label;

  static const all = [
    AdminTable('profiles', 'Profiles'),
    AdminTable('goal_templates', 'Goal templates'),
    AdminTable('user_goals', 'User goals'),
    AdminTable('logs', 'Logs'),
    AdminTable('groups', 'Groups'),
    AdminTable('feedback', 'Feedback'),
    AdminTable('notifications', 'Notifications'),
  ];
}

class AdminRecordsQuery {
  const AdminRecordsQuery({
    required this.table,
    this.includeDeleted = false,
  });

  final String table;
  final bool includeDeleted;

  @override
  bool operator ==(Object other) {
    return other is AdminRecordsQuery &&
        other.table == table &&
        other.includeDeleted == includeDeleted;
  }

  @override
  int get hashCode => Object.hash(table, includeDeleted);
}
