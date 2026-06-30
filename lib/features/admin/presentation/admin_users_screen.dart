import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/utils/scaffold_layout.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/filter_pill.dart';
import '../providers/admin_provider.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  bool _includeDeleted = false;

  Future<void> _refresh() async {
    ref.invalidate(adminUsersProvider(_includeDeleted));
    ref.invalidate(adminDashboardProvider);
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider(_includeDeleted));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'User accounts',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              FilterPill(
                label: 'Show deleted',
                selected: _includeDeleted,
                onTap: () => setState(() => _includeDeleted = !_includeDeleted),
              ),
            ],
          ),
        ),
        Expanded(
          child: usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(error: e, onRetry: _refresh),
            data: (users) {
              if (users.isEmpty) {
                return const Center(child: Text('No users found'));
              }

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    listScrollBottomPadding(context),
                  ),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return Card(
                      child: ListTile(
                        title: Text(user.name),
                        subtitle: Text(
                          [
                            user.email,
                            if (user.handle != null) user.handle!,
                            DateFormat.yMMMd().format(user.createdAt),
                          ].join(' · '),
                        ),
                        leading: CircleAvatar(
                          child: Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (user.isSystemAdmin)
                              const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Icon(Icons.verified_user, size: 20),
                              ),
                            if (user.isDeleted)
                              const InfoPill(label: 'Deleted', emphasis: true)
                            else if (user.isSystemAdmin)
                              const Icon(Icons.lock_outline)
                            else
                              PopupMenuButton<String>(
                                onSelected: (action) async {
                                  if (action == 'delete') {
                                    await ref
                                        .read(adminRepositoryProvider)
                                        .softDelete('profiles', user.id);
                                  } else if (action == 'restore') {
                                    await ref
                                        .read(adminRepositoryProvider)
                                        .restore('profiles', user.id);
                                  }
                                  await _refresh();
                                },
                                itemBuilder: (_) => [
                                  if (!user.isDeleted)
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Soft delete'),
                                    ),
                                  if (user.isDeleted)
                                    const PopupMenuItem(
                                      value: 'restore',
                                      child: Text('Restore'),
                                    ),
                                ],
                              ),
                          ],
                        ),
                        isThreeLine: true,
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
