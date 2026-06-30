import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/admin_table.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/filter_pill.dart';
import '../providers/admin_provider.dart';

class AdminDataScreen extends ConsumerStatefulWidget {
  const AdminDataScreen({super.key});

  @override
  ConsumerState<AdminDataScreen> createState() => _AdminDataScreenState();
}

class _AdminDataScreenState extends ConsumerState<AdminDataScreen> {
  String _table = AdminTable.all.first.key;
  bool _includeDeleted = false;

  AdminRecordsQuery get _query => AdminRecordsQuery(
        table: _table,
        includeDeleted: _includeDeleted,
      );

  Future<void> _refresh() async {
    ref.invalidate(adminRecordsProvider(_query));
  }

  String _recordTitle(Map<String, dynamic> record) {
    return record['title'] as String? ??
        record['name'] as String? ??
        record['display_name'] as String? ??
        record['username'] as String? ??
        record['type'] as String? ??
        record['id'] as String;
  }

  String _recordSubtitle(Map<String, dynamic> record) {
    final parts = <String>[
      record['id'] as String? ?? '',
      if (record['deleted_at'] != null) 'deleted',
      if (record['is_system_admin'] == true) 'system admin',
      if (record['created_at'] != null)
        DateFormat.yMMMd().format(DateTime.parse(record['created_at'] as String)),
    ];
    return parts.where((p) => p.isNotEmpty).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(adminRecordsProvider(_query));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _table,
                  decoration: const InputDecoration(labelText: 'Table'),
                  items: AdminTable.all
                      .map((t) => DropdownMenuItem(value: t.key, child: Text(t.label)))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _table = value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              FilterPill(
                label: 'Deleted',
                selected: _includeDeleted,
                onTap: () => setState(() => _includeDeleted = !_includeDeleted),
              ),
            ],
          ),
        ),
        Expanded(
          child: recordsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(error: e, onRetry: _refresh),
            data: (records) {
              if (records.isEmpty) {
                return const Center(child: Text('No records found'));
              }

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final id = record['id'] as String;
                    final isDeleted = record['deleted_at'] != null;
                    final isSystemAdmin = record['is_system_admin'] == true;

                    return Card(
                      child: ListTile(
                        title: Text(_recordTitle(record)),
                        subtitle: Text(_recordSubtitle(record)),
                        trailing: isSystemAdmin
                            ? const Icon(Icons.lock_outline)
                            : PopupMenuButton<String>(
                                onSelected: (action) async {
                                  if (action == 'delete') {
                                    await ref
                                        .read(adminRepositoryProvider)
                                        .softDelete(_table, id);
                                  } else if (action == 'restore') {
                                    await ref.read(adminRepositoryProvider).restore(_table, id);
                                  }
                                  await _refresh();
                                },
                                itemBuilder: (_) => [
                                  if (!isDeleted)
                                    const PopupMenuItem(value: 'delete', child: Text('Soft delete')),
                                  if (isDeleted)
                                    const PopupMenuItem(value: 'restore', child: Text('Restore')),
                                ],
                              ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
