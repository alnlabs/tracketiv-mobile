import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/feed_item.dart';
import '../../../shared/models/friend_connection.dart';
import '../../../shared/models/goal_invite.dart';
import '../../../shared/models/group_invite.dart';
import '../../../shared/utils/greeting_utils.dart';
import '../../../shared/utils/scaffold_layout.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/tracketiv_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../connections/providers/connections_provider.dart';
import '../../goals/providers/goals_provider.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/feed_date_filter.dart';
import '../providers/feed_date_filter_provider.dart';
import '../providers/feed_provider.dart';
import '../widgets/add_post_sheet.dart';
import '../widgets/feed_card.dart';
import '../widgets/feed_filter_button.dart';
import '../widgets/feed_widget_card.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);
    final items = ref.watch(displayedFeedProvider);
    final filters = ref.watch(feedFiltersProvider);
    final dateFilter = ref.watch(feedDateFilterProvider);
    final goalInvitesAsync = ref.watch(myPendingInvitesProvider);
    final groupInvitesAsync = ref.watch(myPendingGroupInvitesProvider);
    final friendRequestsAsync = ref.watch(incomingFriendRequestsProvider);
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(currentProfileProvider);

    final greeting = profileAsync.maybeWhen(
      data: (profile) => GreetingUtils.withName(profile),
      orElse: () => GreetingUtils.timeOfDay(),
    );

    final isInitialLoad = !feedAsync.hasValue && feedAsync.isLoading;
    final isRefreshing = feedAsync.isRefreshing;

    return Scaffold(
      appBar: TracketivAppBar(
        title: 'Feed',
        subtitle: greeting,
        isLoading: isRefreshing,
        actions: const [
          FeedFilterButton(),
          NotificationBell(),
        ],
      ),
      body: feedAsync.hasError && !feedAsync.hasValue
          ? ErrorView(
              error: feedAsync.error,
              onRetry: () => ref.invalidate(feedProvider),
            )
          : isInitialLoad
              ? const Center(child: CircularProgressIndicator())
              : _FeedBody(
                  items: items,
                  filters: filters,
                  dateFilter: dateFilter,
                  goalInvitesAsync: goalInvitesAsync,
                  groupInvitesAsync: groupInvitesAsync,
                  friendRequestsAsync: friendRequestsAsync,
                  userId: user?.id,
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddPostSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Post'),
      ),
    );
  }
}

class _FeedBody extends ConsumerWidget {
  const _FeedBody({
    required this.items,
    required this.filters,
    required this.dateFilter,
    required this.goalInvitesAsync,
    required this.groupInvitesAsync,
    required this.friendRequestsAsync,
    required this.userId,
  });

  final List<FeedItem> items;
  final Set<FeedFilterOption> filters;
  final FeedDateFilter dateFilter;
  final AsyncValue<List<GoalInvite>> goalInvitesAsync;
  final AsyncValue<List<GroupInvite>> groupInvitesAsync;
  final AsyncValue<List<FriendRequest>> friendRequestsAsync;
  final String? userId;

  Future<void> _onRefresh(WidgetRef ref) async {
    ref.invalidate(feedProvider);
    ref.invalidate(myPendingInvitesProvider);
    ref.invalidate(myPendingGroupInvitesProvider);
    invalidateConnectionData(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasInvites = goalInvitesAsync.maybeWhen(
          data: (v) => v.isNotEmpty,
          orElse: () => false,
        ) ||
        groupInvitesAsync.maybeWhen(
          data: (v) => v.isNotEmpty,
          orElse: () => false,
        ) ||
        friendRequestsAsync.maybeWhen(
          data: (v) => v.isNotEmpty,
          orElse: () => false,
        );

    final hasActiveFilters =
        filters.isNotEmpty || dateFilter.countsAsActiveFilter;

    if (items.isEmpty && !hasInvites) {
      final todayOnly = dateFilter.mode == FeedDateFilterMode.today;
      return RefreshIndicator(
        onRefresh: () => _onRefresh(ref),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                title: hasActiveFilters
                    ? 'No matching posts'
                    : todayOnly
                        ? 'Nothing posted today'
                        : 'Nothing in your feed yet',
                subtitle: hasActiveFilters
                    ? 'Try resetting or changing your filters.'
                    : todayOnly
                        ? 'Switch to All dates in the feed filter, or post an update.'
                        : 'Post a log or update to get started.',
                icon: Icons.dynamic_feed_outlined,
                actionLabel: hasActiveFilters
                    ? 'Reset filters'
                    : todayOnly
                        ? 'Show all dates'
                        : 'Create post',
                onAction: hasActiveFilters
                    ? () async {
                        ref.read(feedFiltersProvider.notifier).state = {};
                        await ref
                            .read(feedDateFilterProvider.notifier)
                            .resetToDefault();
                      }
                    : todayOnly
                        ? () => ref
                            .read(feedDateFilterProvider.notifier)
                            .setFilter(FeedDateFilter.all())
                        : () => showAddPostSheet(context, ref),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _onRefresh(ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          bottom: fabScrollBottomPadding(context),
        ),
        children: [
          _PendingInvitesSection(
            goalInvitesAsync: goalInvitesAsync,
            groupInvitesAsync: groupInvitesAsync,
            friendRequestsAsync: friendRequestsAsync,
            ref: ref,
          ),
          if (items.isEmpty && hasInvites)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Text(
                hasActiveFilters
                    ? 'No posts match your filters.'
                    : 'Activity from your goals will show up here.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ...items.map(
            (item) {
              if (item.isWidget) {
                return FeedWidgetCard(item: item);
              }
              return FeedCard(
                item: item,
                isMe: item.authorId == userId,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PendingInvitesSection extends StatelessWidget {
  const _PendingInvitesSection({
    required this.goalInvitesAsync,
    required this.groupInvitesAsync,
    required this.friendRequestsAsync,
    required this.ref,
  });

  final AsyncValue<List<GoalInvite>> goalInvitesAsync;
  final AsyncValue<List<GroupInvite>> groupInvitesAsync;
  final AsyncValue<List<FriendRequest>> friendRequestsAsync;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        friendRequestsAsync.when(
          data: (requests) => Column(
            children: requests.map((request) {
              return Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_add_outlined),
                        title: Text('Friend request from ${request.otherUserLabel}'),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () async {
                              await ref
                                  .read(connectionsRepositoryProvider)
                                  .respondFriendRequest(
                                    requestId: request.id,
                                    accept: false,
                                  );
                              invalidateConnectionData(ref);
                            },
                            child: const Text('Decline'),
                          ),
                          FilledButton(
                            onPressed: () async {
                              await ref
                                  .read(connectionsRepositoryProvider)
                                  .respondFriendRequest(
                                    requestId: request.id,
                                    accept: true,
                                  );
                              invalidateConnectionData(ref);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Friend request accepted!'),
                                  ),
                                );
                              }
                            },
                            child: const Text('Accept'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        groupInvitesAsync.when(
          data: (invites) => Column(
            children: invites.map((invite) {
              return Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.groups),
                  title: Text('Invite to ${invite.groupName ?? 'a group'}'),
                  subtitle: Text('From ${invite.invitedByName ?? 'someone'}'),
                  trailing: FilledButton(
                    onPressed: () async {
                      await ref.read(goalsRepositoryProvider).acceptGroupInvite(invite.id);
                      ref.invalidate(myPendingGroupInvitesProvider);
                      ref.invalidate(myGroupsProvider);
                      ref.invalidate(myGoalsProvider);
                      ref.invalidate(feedProvider);
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
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.mail),
                  title: Text('Invite to ${invite.goalTitle ?? 'a goal'}'),
                  subtitle: Text('From ${invite.invitedByName ?? 'someone'}'),
                  trailing: FilledButton(
                    onPressed: () async {
                      await ref.read(goalsRepositoryProvider).acceptInvite(invite.id);
                      ref.invalidate(myPendingInvitesProvider);
                      ref.invalidate(myGoalsProvider);
                      ref.invalidate(feedProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invite accepted!')),
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
