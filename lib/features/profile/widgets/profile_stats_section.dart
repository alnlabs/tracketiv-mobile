import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/profile_stats.dart';
import '../../../shared/utils/cadence_utils.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/filter_pill.dart';

class ProfileStatsSection extends StatelessWidget {
  const ProfileStatsSection({
    super.key,
    required this.stats,
    this.canOpenGoals = true,
  });

  final ProfileStats stats;
  final bool canOpenGoals;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Activity', style: AppTypography.sectionTitle(context)),
        const SizedBox(height: 8),
        _ActivityBanner(stats: stats),
        const SizedBox(height: 14),
        Text('Goals', style: AppTypography.sectionTitle(context)),
        const SizedBox(height: 6),
        if (stats.goals.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'No goals tracked yet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          )
        else
          ...stats.goals.map(
            (goal) => _GoalStatCard(goal: goal, canOpen: canOpenGoals),
          ),
      ],
    );
  }
}

class _ActivityBanner extends StatelessWidget {
  const _ActivityBanner({required this.stats});

  final ProfileStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final items = <({IconData icon, String value, String label})>[
      (icon: Icons.local_fire_department_rounded, value: '${stats.currentStreak}d', label: 'Streak'),
      (icon: Icons.edit_note_rounded, value: '${stats.totalLogs}', label: 'Logs'),
      (icon: Icons.calendar_view_week_rounded, value: '${stats.logsThisWeek}', label: 'This week'),
      (icon: Icons.flag_rounded, value: '${stats.activeGoals}', label: 'Active'),
      if (stats.totalGroups > 0)
        (icon: Icons.groups_rounded, value: '${stats.totalGroups}', label: 'Groups'),
    ];

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.45),
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            ],
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: IntrinsicHeight(
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                Expanded(
                  child: _ActivityStatCell(
                    icon: items[i].icon,
                    value: items[i].value,
                    label: items[i].label,
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

class _ActivityStatCell extends StatelessWidget {
  const _ActivityStatCell({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTypography.statValue(context),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTypography.statLabel(context),
        ),
      ],
    );
  }
}

class _GoalStatCard extends StatelessWidget {
  const _GoalStatCard({required this.goal, required this.canOpen});

  final GoalProfileStat goal;
  final bool canOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = goal.isGroup ? colorScheme.tertiary : colorScheme.primary;
    final lastActivity = goal.lastLogAt ?? goal.lastLogDate;
    final lastLabel = lastActivity != null ? _relativeOrDate(lastActivity) : 'No logs yet';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
        child: InkWell(
          onTap: canOpen && goal.isActive ? () => context.push('/goals/${goal.goalId}') : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: accent.withValues(alpha: 0.07),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        goal.isGroup ? Icons.groups_rounded : Icons.flag_rounded,
                        size: 15,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        goal.goalTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cardHeader(context),
                      ),
                    ),
                    if (!goal.isActive)
                      InfoPill(label: goal.goalStatus)
                    else
                      _MetaChip(
                        label: goal.isGroup ? 'Group' : 'Solo',
                        color: accent,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 11,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (goal.isGroup && goal.groupName != null)
                              Text(
                                goal.groupName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _MetaChip(
                                  label: CadenceUtils.label(goal.goalCadence),
                                  color: colorScheme.onSurfaceVariant,
                                  outlined: true,
                                ),
                                if (goal.isActive)
                                  _MetaChip(
                                    label: 'Active',
                                    color: colorScheme.primary,
                                    outlined: true,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 1,
                        color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 9,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '${goal.logCount}',
                                    style: AppTypography.metricOnCard(context),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'log${goal.logCount == 1 ? '' : 's'}',
                                    style: AppTypography.metricUnit(context),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    size: 13,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      lastLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style: AppTypography.metaMuted(context),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _relativeOrDate(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.MMMd().format(time);
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.color,
    this.outlined = false,
  });

  final String label;
  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: outlined ? Border.all(color: color.withValues(alpha: 0.35)) : null,
      ),
      child: Text(
        label,
        style: AppTypography.badge(context, color: color),
      ),
    );
  }
}
