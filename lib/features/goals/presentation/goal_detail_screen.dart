import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/goal_membership.dart';
import '../../../shared/models/log.dart';
import '../../../shared/utils/progress_calculator.dart';
import '../../../shared/utils/streak_calculator.dart';
import '../../../shared/utils/scaffold_layout.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/tracketiv_app_bar.dart';
import '../../../shared/widgets/filter_pill.dart';
import '../../auth/providers/auth_provider.dart';
import '../../logs/providers/logs_provider.dart';
import '../../reminders/providers/reminder_provider.dart';
import '../../social/widgets/comment_section.dart';
import '../../social/widgets/log_reaction_bar.dart';
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
    final isOwnerAsync = ref.watch(isGoalOwnerProvider(goalId));
    final reminderAsync = ref.watch(goalReminderProvider(goalId));

    return Scaffold(
      appBar: TracketivAppBar(
        titleWidget: goalAsync.maybeWhen(
          data: (g) => Text(g.title, style: AppTypography.appBarTitle(context)),
          orElse: () => Text('Goal', style: AppTypography.appBarTitle(context)),
        ),
        actions: [
          goalAsync.maybeWhen(
            data: (goal) {
              if (goal.isGroup) {
                final membersRoute = goal.groupId != null
                    ? '/groups/${goal.groupId}/members'
                    : '/goals/$goalId/members';
                return IconButton(
                  icon: const Icon(Icons.groups_outlined),
                  onPressed: () => context.push(membersRoute),
                );
              }
              return isOwnerAsync.maybeWhen(
                data: (isOwner) => isOwner
                    ? IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit goal',
                        onPressed: () => context.push('/goals/$goalId/edit'),
                      )
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Log reminder',
            onPressed: () => context.push('/goals/$goalId/reminder'),
          ),
        ],
      ),
      body: goalAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(goalDetailProvider(goalId))),
        data: (goal) {
          return logsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(error: e),
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
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    fabScrollBottomPadding(context),
                  ),
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
                                  InfoPill(
                                    icon: Icons.local_fire_department,
                                    label: '$streak day streak',
                                  ),
                                InfoPill(label: goal.cadenceLabel),
                                const Spacer(),
                                InfoPill(label: goal.isGroup ? 'Group' : 'Solo'),
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
                    reminderAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (reminder) {
                        if (reminder?.enabled == true) return const SizedBox.shrink();
                        return Card(
                          margin: const EdgeInsets.only(top: 8),
                          child: ListTile(
                            leading: const Icon(Icons.notifications_outlined),
                            title: const Text('Set a log reminder'),
                            subtitle: const Text(
                              'Get a daily notification to log progress for this goal.',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('/goals/$goalId/reminder'),
                          ),
                        );
                      },
                    ),
                    if (myLogs.length >= 2) ...[
                      const SizedBox(height: 16),
                      Text('Your progress', style: AppTypography.sectionTitle(context)),
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
                      data: (members) {
                        if (!goal.isGroup) return const SizedBox.shrink();
                        final membersRoute = goal.groupId != null
                            ? '/groups/${goal.groupId}/members'
                            : '/goals/$goalId/members';
                        return Card(
                          child: ListTile(
                            leading: _MemberAvatars(members: members),
                            title: Text('${members.length} group member${members.length == 1 ? '' : 's'}'),
                            subtitle: goal.groupName != null
                                ? Text('${goal.groupName} · view members')
                                : const Text('View members and invite others'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(membersRoute),
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 8),
                    Text('Activity feed', style: AppTypography.sectionTitle(context)),
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
                                  LogReactionBar(logId: log.id),
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

class _MemberAvatars extends StatelessWidget {
  const _MemberAvatars({required this.members});

  final List<GoalMembership> members;

  @override
  Widget build(BuildContext context) {
    final shown = members.take(3).toList();
    return SizedBox(
      width: 56,
      height: 32,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 18.0,
              child: CircleAvatar(
                radius: 14,
                child: Text(
                  (shown[i].displayName ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
