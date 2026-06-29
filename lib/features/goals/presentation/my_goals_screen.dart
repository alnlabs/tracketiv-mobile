import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/utils/progress_calculator.dart';
import '../../../shared/utils/streak_calculator.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../logs/providers/logs_provider.dart';
import '../providers/goals_provider.dart';

class MyGoalsScreen extends ConsumerWidget {
  const MyGoalsScreen({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(myGoalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Goals')),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(message: e.toString(), onRetry: () => ref.invalidate(myGoalsProvider)),
        data: (goals) {
          if (goals.isEmpty) {
            return EmptyState(
              title: 'No active goals yet',
              subtitle: 'Browse predefined goals and start tracking your progress.',
              icon: Icons.flag_outlined,
              actionLabel: 'Explore goals',
              onAction: () => context.go('/home/catalog'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myGoalsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: goals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final goal = goals[index];
                return _GoalCard(goal: goal, icon: _iconForMetric(goal.metricType));
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/home/catalog'),
        icon: const Icon(Icons.add),
        label: const Text('Join goal'),
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.goal, required this.icon});

  final dynamic goal;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(myGoalLogsProvider(goal.id));

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/goals/${goal.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: logsAsync.when(
            loading: () => _GoalCardContent(goal: goal, icon: icon),
            error: (_, __) => _GoalCardContent(goal: goal, icon: icon),
            data: (logs) {
              final streak = StreakCalculator.calculate(logs);
              final latest = logs.isNotEmpty ? logs.first.value : null;
              final progress = ProgressCalculator.percent(
                startValue: goal.startValue,
                currentValue: latest,
                targetValue: goal.targetValue,
              );
              return _GoalCardContent(
                goal: goal,
                icon: icon,
                streak: streak,
                latestValue: latest,
                progress: progress,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GoalCardContent extends StatelessWidget {
  const _GoalCardContent({
    required this.goal,
    required this.icon,
    this.streak,
    this.latestValue,
    this.progress,
  });

  final dynamic goal;
  final IconData icon;
  final int? streak;
  final double? latestValue;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(goal.title, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    '${goal.mode == 'group' ? 'Group' : 'Solo'} · ${goal.cadence}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (streak != null && streak! > 0)
              Chip(
                avatar: const Icon(Icons.local_fire_department, size: 16),
                label: Text('$streak day streak'),
              ),
          ],
        ),
        if (goal.targetValue != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              if (latestValue != null)
                Text(
                  'Latest: $latestValue ${goal.metricUnit ?? ''}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              const Spacer(),
              if (goal.targetDate != null)
                Text(
                  'Target: ${DateFormat.yMMMd().format(goal.targetDate!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress! / 100),
            const SizedBox(height: 4),
            Text('${progress!.toStringAsFixed(0)}% toward goal'),
          ],
        ],
      ],
    );
  }
}
