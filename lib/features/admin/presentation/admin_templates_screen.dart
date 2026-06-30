import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/scaffold_layout.dart';
import '../../../shared/models/goal_template.dart';
import '../../../shared/widgets/error_view.dart';
import '../../goals/providers/goals_provider.dart';
import '../providers/admin_provider.dart';
import 'admin_template_form_screen.dart';

class AdminTemplatesScreen extends ConsumerWidget {
  const AdminTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(adminTemplatesProvider);

    return templatesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(error: e,
        onRetry: () => ref.invalidate(adminTemplatesProvider),
      ),
      data: (templates) {
        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  'Default goal templates',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(adminTemplatesProvider);
                    ref.invalidate(goalTemplatesProvider(null));
                  },
                  child: templates.isEmpty
                      ? ListView(
                          padding: EdgeInsets.only(
                            bottom: fabScrollBottomPadding(context),
                          ),
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Text('No goal templates yet')),
                          ],
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            16,
                            16,
                            fabScrollBottomPadding(context),
                          ),
                          itemCount: templates.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final template = templates[index];
                            return _TemplateCard(template: template);
                          },
                        ),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const AdminTemplateFormScreen()),
              );
              ref.invalidate(adminTemplatesProvider);
              ref.invalidate(goalTemplatesProvider(null));
            },
            icon: const Icon(Icons.add),
            label: const Text('Add template'),
          ),
        );
      },
    );
  }
}

class _TemplateCard extends ConsumerWidget {
  const _TemplateCard({required this.template});

  final GoalTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text(template.title),
        subtitle: Text(
          '${template.category} · ${template.cadence} · ${template.metricType}'
          '${template.metricUnit != null ? ' (${template.metricUnit})' : ''}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'edit') {
              await Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => AdminTemplateFormScreen(template: template),
                ),
              );
              ref.invalidate(adminTemplatesProvider);
              ref.invalidate(goalTemplatesProvider(null));
            } else if (value == 'delete') {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete template?'),
                  content: Text('Soft-delete "${template.title}" from the catalog?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(adminRepositoryProvider).deleteTemplate(template.id);
                ref.invalidate(adminTemplatesProvider);
                ref.invalidate(goalTemplatesProvider(null));
              }
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}
