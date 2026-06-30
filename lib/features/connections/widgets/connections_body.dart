import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/friend_connection.dart';
import '../../../shared/models/invitable_user.dart';
import '../../../shared/utils/scaffold_layout.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/invitable_user_row.dart';
import '../../auth/providers/auth_provider.dart';
import '../../goals/providers/goals_provider.dart';
import '../providers/connections_provider.dart';
import 'package:tracketiv/shared/utils/api_error_formatter.dart';

class ConnectionsBody extends ConsumerStatefulWidget {
  const ConnectionsBody({super.key});

  @override
  ConsumerState<ConnectionsBody> createState() => _ConnectionsBodyState();
}

class _ConnectionsBodyState extends ConsumerState<ConnectionsBody> {
  final _searchController = TextEditingController();
  List<InvitableUser> _searchResults = [];
  bool _isSearching = false;
  bool _isSending = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final results =
          await ref.read(goalsRepositoryProvider).searchUsersForInvite(query);
      final me = ref.read(currentUserProvider)?.id;
      setState(() {
        _searchResults = results.where((u) => u.id != me).toList();
      });
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _sendRequest(InvitableUser user) async {
    setState(() => _isSending = true);
    try {
      await ref.read(connectionsRepositoryProvider).sendFriendRequest(user.id);
      invalidateConnectionData(ref);
      ref.invalidate(friendshipStatusProvider(user.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Friend request sent to ${user.label}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toUserMessage())),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _respond(FriendRequest request, bool accept) async {
    try {
      await ref.read(connectionsRepositoryProvider).respondFriendRequest(
            requestId: request.id,
            accept: accept,
          );
      invalidateConnectionData(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'You are now friends' : 'Request declined'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toUserMessage())),
        );
      }
    }
  }

  Future<void> _removeFriend(FriendConnection friend) async {
    try {
      await ref.read(connectionsRepositoryProvider).removeFriend(friend.friendId);
      invalidateConnectionData(ref);
      ref.invalidate(friendshipStatusProvider(friend.friendId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toUserMessage())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(myFriendsProvider);
    final requestsAsync = ref.watch(friendRequestsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        invalidateConnectionData(ref);
      },
      child: ListView(
        padding: EdgeInsets.only(bottom: fabScrollBottomPadding(context)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Connect with friends to see their goal activity in your feed.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          requestsAsync.when(
            data: (requests) {
              if (requests.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Requests',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  ...requests.map((request) {
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.otherUserLabel,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              request.isIncoming ? 'Wants to connect' : 'Request sent',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            if (request.isIncoming) ...[
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () => _respond(request, false),
                                    child: const Text('Decline'),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: () => _respond(request, true),
                                    child: const Text('Accept'),
                                  ),
                                ],
                              ),
                            ] else ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _respond(request, false),
                                  child: const Text('Cancel'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Find people',
                hintText: 'Name or @username',
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _search,
                      ),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          ..._searchResults.map((user) {
            return InvitableUserRow(
              user: user,
              actionLabel: 'Add',
              isActionEnabled: !_isSending,
              onAction: () => _sendRequest(user),
              onTap: () => context.push('/users/${user.id}'),
            );
          }),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Friends',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          friendsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(myFriendsProvider),
            ),
            data: (friends) {
              if (friends.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: EmptyState(
                    title: 'No friends yet',
                    subtitle: 'Search above or visit a profile to send a request.',
                    icon: Icons.people_outline,
                  ),
                );
              }
              return Column(
                children: friends.map((friend) {
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(friend.label[0].toUpperCase()),
                    ),
                    title: Text(friend.label),
                    subtitle: friend.username != null ? Text('@${friend.username}') : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.person_remove_outlined),
                      tooltip: 'Remove friend',
                      onPressed: () => _removeFriend(friend),
                    ),
                    onTap: () => context.push('/users/${friend.friendId}'),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
