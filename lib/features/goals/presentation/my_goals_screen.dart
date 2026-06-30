import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/goal_invite.dart';
import '../../../shared/models/group_invite.dart';
import '../../../shared/models/user_goal.dart';
import '../../../shared/utils/progress_calculator.dart';
import '../../../shared/utils/streak_calculator.dart';
import '../../../shared/utils/scaffold_layout.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/tracketiv_app_bar.dart';
import '../../../shared/widgets/filter_pill.dart';
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
    final goalInvitesAsync = ref.watch(myPendingInvitesProvider);
    final groupInvitesAsync = ref.watch(myPendingGroupInvitesProvider);

    return Scaffold(
      appBar: const TracketivAppBar(title: 'My Goals'),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(myGoalsProvider)),
        data: (goals) {
          final soloGoals = goals.where((g) => g.groupId == null).toList();
          final groupedGoals = <String, List<UserGoal>>{};
          for (final goal in goals) {
            if (goal.groupId != null) {
              groupedGoals.putIfAbsent(goal.groupId!, () => []).add(goal);
            }
          }

          final hasContent = soloGoals.isNotEmpty || groupedGoals.isNotEmpty;

          if (!hasContent) {
            return Column(
              children: [
                _PendingInvitesBanner(
                  goalInvitesAsync: goalInvitesAsync,
                  groupInvitesAsync: groupInvitesAsync,
                  ref: ref,
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: fabScrollBottomPadding(context)),
                    child: EmptyState(
                      title: 'No active goals yet',
                      subtitle: 'Start a solo goal or create a group to track with friends.',
                      icon: Icons.flag_outlined,
                      actionLabel: 'Create goal',
                      onAction: () => _showCreateGoalMenu(context),
                    ),
                  ),
                ),
              ],
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myGoalsProvider);
              ref.invalidate(myGroupsProvider);
              ref.invalidate(myPendingInvitesProvider);
              ref.invalidate(myPendingGroupInvitesProvider);
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                12,
                12,
                12,
                fabScrollBottomPadding(context),
              ),
              children: [
                _PendingInvitesBanner(
                  goalInvitesAsync: goalInvitesAsync,
                  groupInvitesAsync: groupInvitesAsync,
                  ref: ref,
                ),
                if (groupedGoals.isNotEmpty) ...[
                  Text('Groups', style: AppTypography.sectionTitle(context)),
                  const SizedBox(height: 6),
                  ...groupedGoals.entries.map((entry) {
                    final groupName = entry.value.first.groupName ?? 'Group';
                    return _GroupSection(
                      groupId: entry.key,
                      groupName: groupName,
                      goals: entry.value,
                      iconForMetric: _iconForMetric,
                    );
                  }),
                  const SizedBox(height: 10),
                ],
                if (soloGoals.isNotEmpty) ...[
                  Text('Solo goals', style: AppTypography.sectionTitle(context)),
                  const SizedBox(height: 6),
                  ...soloGoals.map(
                    (goal) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _GoalCard(goal: goal, icon: _iconForMetric(goal.metricType)),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateGoalMenu(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  void _showCreateGoalMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  'What would you like to do?',
                  style: AppTypography.sheetTitle(ctx),
                ),
              ),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: const Text('Track on my own'),
                subtitle: const Text('A personal solo goal'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/home/catalog');
                },
              ),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.groups_outlined)),
                title: const Text('Start a group'),
                subtitle: const Text('Invite friends, then add goals together'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/groups/create');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.goal, required this.icon});

  final UserGoal goal;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(myGoalLogsProvider(goal.id));

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/goals/${goal.id}'),
        onLongPress: goal.isGroup
            ? null
            : () => context.push('/goals/${goal.id}/edit'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
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
              IconButton(
                icon: const Icon(Icons.notifications_outlined, size: 18),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Log reminder',
                onPressed: () => context.push('/goals/${goal.id}/reminder'),
              ),
              if (!goal.isGroup)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Edit goal',
                  onPressed: () => context.push('/goals/${goal.id}/edit'),
                ),
            ],
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

  final UserGoal goal;
  final IconData icon;
  final int? streak;
  final double? latestValue;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 16,
              child: Icon(icon, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cardTitle(context, weight: FontWeight.w600),
                  ),
                  Text(
                    goal.groupName != null
                        ? '${goal.groupName} · ${goal.cadenceLabel}'
                        : '${goal.isGroup ? 'Group' : 'Solo'} · ${goal.cadenceLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (streak != null && streak! > 0)
              InfoPill(
                icon: Icons.local_fire_department,
                label: '$streak d',
              ),
          ],
        ),
        if (goal.targetValue != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (latestValue != null)
                Expanded(
                  child: Text(
                    'Latest: $latestValue ${goal.metricUnit ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              if (goal.targetDate != null)
                Text(
                  DateFormat.MMMd().format(goal.targetDate!),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                minHeight: 4,
                value: progress! / 100,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${progress!.toStringAsFixed(0)}% toward goal',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.groupId,
    required this.groupName,
    required this.goals,
    required this.iconForMetric,
  });

  final String groupId;
  final String groupName;
  final List<UserGoal> goals;
  final IconData Function(String) iconForMetric;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/groups/$groupId'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    child: Icon(Icons.groups, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          groupName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cardTitle(context, weight: FontWeight.w600),
                        ),
                        Text(
                          '${goals.length} goal${goals.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Add goal to group',
                    onPressed: () => context.push('/home/catalog?groupId=$groupId'),
                  ),
                ],
              ),
              if (goals.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...goals.take(3).map(
                      (goal) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => context.push('/goals/${goal.id}'),
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(iconForMetric(goal.metricType), size: 14),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          goal.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.labelMedium,
                                        ),
                                      ),
                                      Text(
                                        goal.cadenceLabel,
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.notifications_outlined, size: 16),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              tooltip: 'Log reminder',
                              onPressed: () => context.push('/goals/${goal.id}/reminder'),
                            ),
                          ],
                        ),
                      ),
                    ),
                if (goals.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '+ ${goals.length - 3} more',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingInvitesBanner extends StatelessWidget {
  const _PendingInvitesBanner({
    required this.goalInvitesAsync,
    required this.groupInvitesAsync,
    required this.ref,
  });

  final AsyncValue<List<GoalInvite>> goalInvitesAsync;
  final AsyncValue<List<GroupInvite>> groupInvitesAsync;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        groupInvitesAsync.when(
          data: (invites) => Column(
            children: invites.map((invite) {
              return Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: const Icon(Icons.groups, size: 20),
                  title: Text(
                    'Invite to ${invite.groupName ?? 'a group'}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  subtitle: Text(
                    'From ${invite.invitedByName ?? 'someone'}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  trailing: FilledButton(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () async {
                      await ref.read(goalsRepositoryProvider).acceptGroupInvite(invite.id);
                      ref.invalidate(myPendingGroupInvitesProvider);
                      ref.invalidate(myGroupsProvider);
                      ref.invalidate(myGoalsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('You joined the group!')),
                        );
                      }
                    },
                    child: const Text('Join'),
                  ),
                ),
              );
            }).toList(),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        goalInvitesAsync.when(
          data: (invites) => Column(
            children: invites.map((invite) {
              return Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: const Icon(Icons.mail, size: 20),
                  title: Text(
                    'Invite to ${invite.goalTitle ?? 'a group goal'}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  subtitle: Text(
                    'From ${invite.invitedByName ?? 'someone'}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  trailing: FilledButton(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () async {
                      await ref.read(goalsRepositoryProvider).acceptInvite(invite.id);
                      ref.invalidate(myPendingInvitesProvider);
                      ref.invalidate(myGoalsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('You joined the group!')),
                        );
                      }
                    },
                    child: const Text('Join'),
                  ),
                ),
              );
            }).toList(),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
