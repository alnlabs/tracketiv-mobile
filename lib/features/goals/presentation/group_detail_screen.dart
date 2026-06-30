import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../feed/providers/feed_widget_provider.dart';
import '../../../shared/utils/feed_widget_time.dart';
import '../../../shared/models/group_membership.dart';
import '../../../shared/models/user_goal.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/utils/scaffold_layout.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/tracketiv_app_bar.dart';
import '../providers/goals_provider.dart';
import 'package:tracketiv/shared/utils/api_error_formatter.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

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
    final groupAsync = ref.watch(groupDetailProvider(groupId));
    final goalsAsync = ref.watch(groupGoalsProvider(groupId));
    final membersAsync = ref.watch(groupMembersProvider(groupId));

    return Scaffold(
      appBar: TracketivAppBar(
        titleWidget: groupAsync.maybeWhen(
          data: (g) => Text(
            g.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.appBarTitle(context),
          ),
          orElse: () => Text('Group', style: AppTypography.appBarTitle(context)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined, size: 22),
            tooltip: 'Members',
            onPressed: () => context.push('/groups/$groupId/members'),
          ),
        ],
      ),
      body: groupAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(groupDetailProvider(groupId)),
        ),
        data: (group) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(groupDetailProvider(groupId));
              ref.invalidate(groupGoalsProvider(groupId));
              ref.invalidate(groupMembersProvider(groupId));
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                12,
                12,
                12,
                fabScrollBottomPadding(context),
              ),
              children: [
                membersAsync.when(
                  data: (members) => _MembersBanner(
                    members: members,
                    onTap: () => context.push('/groups/$groupId/members'),
                  ),
                  loading: () => const SizedBox(height: 72),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                if (group.description != null && group.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    group.description!.trim(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                  ),
                ],
                _GroupFeedWidgetsTile(groupId: groupId),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text('Goals', style: AppTypography.sectionTitle(context)),
                    ),
                    TextButton.icon(
                      onPressed: () => context.push('/home/catalog?groupId=$groupId'),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                goalsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(e.toUserMessage()),
                  ),
                  data: (goals) {
                    if (goals.isEmpty) {
                      return Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
                          child: EmptyState(
                            title: 'No group goals yet',
                            subtitle: 'Pick something to track together — weight, steps, water, and more.',
                            icon: Icons.flag_outlined,
                            actionLabel: 'Pick a goal',
                            onAction: () => context.push('/home/catalog?groupId=$groupId'),
                          ),
                        ),
                      );
                    }

                    return Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (var i = 0; i < goals.length; i++) ...[
                            _GroupGoalTile(
                              goal: goals[i],
                              icon: _iconForMetric(goals[i].metricType),
                              onTap: () => context.push('/goals/${goals[i].id}'),
                            ),
                            if (i < goals.length - 1)
                              Divider(
                                height: 1,
                                indent: 52,
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant
                                    .withValues(alpha: 0.5),
                              ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: goalsAsync.maybeWhen(
        data: (goals) => goals.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: () => context.push('/home/catalog?groupId=$groupId'),
                icon: const Icon(Icons.add),
                label: const Text('Add goal'),
              )
            : null,
        orElse: () => null,
      ),
    );
  }
}

class _MembersBanner extends StatelessWidget {
  const _MembersBanner({
    required this.members,
    required this.onTap,
  });

  final List<GroupMembership> members;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = colorScheme.tertiary;

    return Material(
      color: accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          child: Row(
            children: [
              _MemberAvatarStack(members: members),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${members.length} member${members.length == 1 ? '' : 's'}',
                      style: AppTypography.cardTitle(context, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Invite friends · manage members',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberAvatarStack extends StatelessWidget {
  const _MemberAvatarStack({required this.members});

  final List<GroupMembership> members;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shown = members.take(4).toList();
    const size = 30.0;
    const overlap = 22.0;
    final width = shown.isEmpty ? size : size + (shown.length - 1) * overlap;

    if (shown.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: colorScheme.tertiaryContainer,
        child: Icon(Icons.groups_outlined, size: 16, color: colorScheme.onTertiaryContainer),
      );
    }

    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * overlap,
              child: CircleAvatar(
                radius: size / 2,
                backgroundColor: colorScheme.surface,
                backgroundImage: _avatarUrl(shown[i]) != null
                    ? NetworkImage(_avatarUrl(shown[i])!)
                    : null,
                child: _avatarUrl(shown[i]) == null
                    ? Text(
                        _initial(shown[i]),
                        style: AppTypography.avatarInitial(),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  String? _avatarUrl(GroupMembership member) =>
      member.profile?['avatar_url'] as String?;

  String _initial(GroupMembership member) {
    final label = member.publicLabel;
    return label.isNotEmpty ? label[0].toUpperCase() : 'U';
  }
}

class _GroupGoalTile extends StatelessWidget {
  const _GroupGoalTile({
    required this.goal,
    required this.icon,
    required this.onTap,
  });

  final UserGoal goal;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(icon, size: 16, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 10),
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
                  const SizedBox(height: 2),
                  Text(
                    '${goal.cadenceLabel} · ${goal.metricUnit ?? goal.metricType}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupFeedWidgetsTile extends ConsumerWidget {
  const _GroupFeedWidgetsTile({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwnerAsync = ref.watch(isGroupOwnerProvider(groupId));
    final widgetAsync = ref.watch(groupQuoteWidgetProvider(groupId));

    return isOwnerAsync.when(
      data: (isOwner) {
        if (!isOwner) return const SizedBox.shrink();

        final subtitle = widgetAsync.maybeWhen(
          data: (widget) {
            if (widget == null) {
              return 'Install — one quote in the group Feed each day';
            }
            return widget.enabled
                ? formatDailyQuoteScheduleFromStorage(widget.showTime)
                : 'Paused';
          },
          orElse: () => 'Set time and quote for the group Feed',
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text('Group add-ons', style: AppTypography.sectionTitle(context)),
            const SizedBox(height: 6),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.format_quote_rounded),
                title: const Text('Daily quote'),
                subtitle: Text(subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/feed/widgets/group/$groupId/quote'),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
