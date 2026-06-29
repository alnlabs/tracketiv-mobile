import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/goal_template.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../providers/goals_provider.dart';

class GoalCatalogScreen extends ConsumerStatefulWidget {
  const GoalCatalogScreen({super.key});

  @override
  ConsumerState<GoalCatalogScreen> createState() => _GoalCatalogScreenState();
}

class _GoalCatalogScreenState extends ConsumerState<GoalCatalogScreen> {
  String _category = 'all';

  static const _categories = {
    'all': 'All',
    'fitness': 'Fitness',
    'health': 'Health',
    'mindfulness': 'Mindfulness',
    'learning': 'Learning',
    'finance': 'Finance',
  };

  IconData _iconForTemplate(GoalTemplate template) {
    switch (template.icon) {
      case 'monitor_weight':
        return Icons.monitor_weight_outlined;
      case 'directions_walk':
        return Icons.directions_walk;
      case 'water_drop':
        return Icons.water_drop_outlined;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'menu_book':
        return Icons.menu_book;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'savings':
        return Icons.savings_outlined;
      case 'bedtime':
        return Icons.bedtime_outlined;
      default:
        return Icons.flag_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(goalTemplatesProvider(_category == 'all' ? null : _category));

    return Scaffold(
      appBar: AppBar(title: const Text('Explore Goals')),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: _categories.entries.map((entry) {
                final selected = _category == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(entry.value),
                    selected: selected,
                    onSelected: (_) => setState(() => _category = entry.key),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: templatesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(goalTemplatesProvider(_category == 'all' ? null : _category)),
              ),
              data: (templates) {
                if (templates.isEmpty) {
                  return const EmptyState(
                    title: 'No goals found',
                    subtitle: 'Try a different category or check back later.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: templates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final template = templates[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Icon(_iconForTemplate(template))),
                        title: Text(template.title),
                        subtitle: Text(template.description ?? ''),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/goals/join/${template.id}', extra: template),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
