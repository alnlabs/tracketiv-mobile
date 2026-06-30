import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/post_type.dart';
import '../../../shared/models/user_goal.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../goals/providers/goals_provider.dart';
import 'package:tracketiv/shared/utils/api_error_formatter.dart';

void showAddPostSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _AddPostSheet(ref: ref),
  );
}

class _AddPostSheet extends ConsumerStatefulWidget {
  const _AddPostSheet({required this.ref});

  final WidgetRef ref;

  @override
  ConsumerState<_AddPostSheet> createState() => _AddPostSheetState();
}

class _AddPostSheetState extends ConsumerState<_AddPostSheet> {
  PostType? _selectedType;

  IconData _iconForMetric(String type) {
    switch (type) {
      case 'weight':
        return Icons.monitor_weight_outlined;
      case 'steps':
        return Icons.directions_walk;
      case 'volume':
        return Icons.water_drop_outlined;
      default:
        return Icons.track_changes;
    }
  }

  void _selectType(PostType type) {
    setState(() => _selectedType = type);
  }

  void _openLog(UserGoal goal) {
    final type = _selectedType!;
    Navigator.pop(context);
    context.push('/goals/${goal.id}/log?type=${type.queryValue}');
  }

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(myGoalsProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  if (_selectedType != null)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => setState(() => _selectedType = null),
                    ),
                  Expanded(
                    child: Text(
                      _selectedType == null ? 'Create post' : 'Choose a goal',
                      style: AppTypography.sheetTitle(context),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            if (_selectedType == null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'What do you want to post?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              ...PostType.values.map(
                (type) => ListTile(
                  leading: CircleAvatar(child: Icon(type.icon)),
                  title: Text(type.label),
                  subtitle: Text(type.subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectType(type),
                ),
              ),
              const SizedBox(height: 8),
            ] else
              goalsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(e.toUserMessage()),
                ),
                data: (goals) {
                  if (goals.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: EmptyState(
                        title: 'No goals yet',
                        subtitle: 'Create a goal first, then you can post updates here.',
                        icon: Icons.flag_outlined,
                        actionLabel: 'Go to goals',
                        onAction: () {
                          Navigator.pop(context);
                          context.go('/home/goals');
                        },
                      ),
                    );
                  }

                  final solo = goals.where((g) => g.groupId == null).toList();
                  final grouped = <String, List<UserGoal>>{};
                  for (final g in goals) {
                    if (g.groupId != null) {
                      grouped.putIfAbsent(g.groupId!, () => []).add(g);
                    }
                  }

                  return Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                      children: [
                        if (solo.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: Text('Solo goals', style: Theme.of(context).textTheme.labelLarge),
                          ),
                          ...solo.map((g) => _GoalTile(goal: g, icon: _iconForMetric(g.metricType), onTap: () => _openLog(g))),
                        ],
                        ...grouped.entries.map((entry) {
                          final name = entry.value.first.groupName ?? 'Group';
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                child: Text(name, style: Theme.of(context).textTheme.labelLarge),
                              ),
                              ...entry.value.map(
                                (g) => _GoalTile(
                                  goal: g,
                                  icon: _iconForMetric(g.metricType),
                                  onTap: () => _openLog(g),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal, required this.icon, required this.onTap});

  final UserGoal goal;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(goal.title),
      subtitle: Text('${goal.cadenceLabel} · ${goal.metricUnit ?? goal.metricType}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
