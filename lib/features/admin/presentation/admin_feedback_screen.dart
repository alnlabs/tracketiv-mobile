import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/utils/scaffold_layout.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/filter_pill.dart';
import '../providers/admin_provider.dart';

class AdminFeedbackScreen extends ConsumerWidget {
  const AdminFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedbackAsync = ref.watch(adminFeedbackProvider);

    return feedbackAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(error: e,
        onRetry: () => ref.invalidate(adminFeedbackProvider),
      ),
      data: (items) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                'User feedback',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('No feedback submissions yet'))
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(adminFeedbackProvider);
                        ref.invalidate(adminDashboardProvider);
                      },
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          listScrollBottomPadding(context),
                        ),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Card(
                            child: ListTile(
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text('${item.typeLabel} · ${item.authorLabel}'),
                                  ),
                                  if (item.isDeleted)
                                    const InfoPill(label: 'Deleted', emphasis: true),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(item.message),
                                  const SizedBox(height: 4),
                                  Text(
                                    [
                                      if (item.contactEmail != null) item.contactEmail!,
                                      DateFormat.yMMMd().add_jm().format(item.createdAt),
                                    ].join(' · '),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (action) async {
                                  if (action == 'delete') {
                                    await ref
                                        .read(adminRepositoryProvider)
                                        .softDelete('feedback', item.id);
                                  } else if (action == 'restore') {
                                    await ref
                                        .read(adminRepositoryProvider)
                                        .restore('feedback', item.id);
                                  }
                                  ref.invalidate(adminFeedbackProvider);
                                  ref.invalidate(adminDashboardProvider);
                                },
                                itemBuilder: (_) => [
                                  if (!item.isDeleted)
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Soft delete'),
                                    ),
                                  if (item.isDeleted)
                                    const PopupMenuItem(
                                      value: 'restore',
                                      child: Text('Restore'),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
