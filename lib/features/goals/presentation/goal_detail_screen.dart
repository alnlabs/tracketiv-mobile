import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/log.dart';
import '../../../shared/utils/progress_calculator.dart';
import '../../../shared/utils/streak_calculator.dart';
import '../../../shared/widgets/error_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../../logs/providers/logs_provider.dart';
import '../../social/widgets/comment_section.dart';
import '../../social/widgets/reaction_bar.dart';
import '../providers/goals_provider.dart';

class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalAsync = ref.watch(goalDetailProvider(goalId));
    final logsAsync = ref.watch(goalLogsProvider(goalId));
    final membersAsync = ref.watch(goalMembersProvider(goalId));
    final everyoneLoggedAsync = ref.watch(everyoneLoggedTodayProvider(goalId));
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: goalAsync.maybeWhen(data: (g) => Text(g.title), orElse: () => const Text('Goal')),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/goals/$goalId/reminder'),
          ),
        ],
      ),
      body: goalAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(message: e.toString(), onRetry: () => ref.invalidate(goalDetailProvider(goalId))),
        data: (goal) {
          return logsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(message: e.toString()),
            data: (logs) {
              final myLogs = user != null
                  ? logs.where((l) => l.authorId == user.id).toList()
                  : <LogEntry>[];
              final streak = StreakCalculator.calculate(myLogs);
              final latest = myLogs.isNotEmpty ? myLogs.first.value : null;
              final progress = ProgressCalculator.percent(
                startValue: goal.startValue,
                currentValue: latest,
                targetValue: goal.targetValue,
              );

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(goalDetailProvider(goalId));
                  ref.invalidate(goalLogsProvider(goalId));
                  ref.invalidate(goalMembersProvider(goalId));
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (goal.isGroup)
                      everyoneLoggedAsync.when(
                        data: (allLogged) => allLogged
                            ? Card(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                child: const ListTile(
                                  leading: Icon(Icons.check_circle),
                                  title: Text('Everyone logged today!'),
                                ),
                              )
                            : const SizedBox.shrink(),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (streak > 0)
                                  Chip(
                                    avatar: const Icon(Icons.local_fire_department, size: 16),
                                    label: Text('$streak day streak'),
                                  ),
                                const Spacer(),
                                Chip(label: Text(goal.isGroup ? 'Group' : 'Solo')),
                              ],
                            ),
                            if (progress != null) ...[
                              const SizedBox(height: 12),
                              LinearProgressIndicator(value: progress / 100),
                              Text('${progress.toStringAsFixed(0)}% progress'),
                            ],
                            if (goal.targetValue != null)
                              Text('Target: ${goal.targetValue} ${goal.metricUnit ?? ''}'),
                          ],
                        ),
                      ),
                    ),
                    if (myLogs.length >= 2) ...[
                      const SizedBox(height: 16),
                      Text('Your progress', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 180,
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            titlesData: const FlTitlesData(show: false),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: myLogs.reversed.toList().asMap().entries.map((e) {
                                  return FlSpot(e.key.toDouble(), e.value.value ?? 0);
                                }).toList(),
                                isCurved: true,
                                dotData: const FlDotData(show: true),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    membersAsync.when(
                      data: (members) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('${members.length} member${members.length == 1 ? '' : 's'}'),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 8),
                    Text('Activity feed', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (logs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('No logs yet. Be the first to log!')),
                      )
                    else
                      ...logs.map((log) => Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        child: Text(
                                          (log.authorName ?? 'U')[0].toUpperCase(),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(log.authorName ?? 'User',
                                                style: Theme.of(context).textTheme.titleSmall),
                                            Text(DateFormat.yMMMd().format(log.logDate),
                                                style: Theme.of(context).textTheme.bodySmall),
                                          ],
                                        ),
                                      ),
                                      if (log.value != null)
                                        Text(
                                          '${log.value} ${goal.metricUnit ?? ''}',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                    ],
                                  ),
                                  if (log.note != null && log.note!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(log.note!),
                                  ],
                                  const SizedBox(height: 8),
                                  ReactionBar(logId: log.id),
                                  CommentSection(logId: log.id),
                                ],
                              ),
                            ),
                          )),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/goals/$goalId/log'),
        icon: const Icon(Icons.add),
        label: const Text('Add log'),
      ),
    );
  }
}
