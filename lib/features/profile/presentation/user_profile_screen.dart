import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/friend_connection.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/utils/scaffold_layout.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/tracketiv_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../connections/providers/connections_provider.dart';
import 'package:tracketiv/shared/utils/api_error_formatter.dart';
import '../providers/profile_provider.dart';
import '../widgets/profile_stats_section.dart';

/// Public profile view — stats and basics visible to any signed-in user.
class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(userId));
    final statsAsync = ref.watch(userProfileStatsProvider(userId));
    final currentUser = ref.watch(currentUserProvider);
    final isMe = currentUser?.id == userId;

    if (isMe) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/home/profile');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: TracketivAppBar(
        titleWidget: profileAsync.maybeWhen(
          data: (p) => Text(
            p?.publicName ?? 'Profile',
            style: AppTypography.appBarTitle(context),
          ),
          orElse: () => Text('Profile', style: AppTypography.appBarTitle(context)),
        ),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e,
          onRetry: () {
            ref.invalidate(userProfileProvider(userId));
            ref.invalidate(userProfileStatsProvider(userId));
          },
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('User not found'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(userProfileProvider(userId));
              ref.invalidate(userProfileStatsProvider(userId));
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                12,
                12,
                12,
                listScrollBottomPadding(context),
              ),
              children: [
                _PublicProfileHeader(profile: profile),
                const SizedBox(height: 12),
                _FriendshipActionBar(userId: userId),
                const SizedBox(height: 12),
                statsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  error: (e, _) => ErrorView(error: e,
                    onRetry: () => ref.invalidate(userProfileStatsProvider(userId)),
                  ),
                  data: (stats) {
                    if (stats == null) return const SizedBox.shrink();
                    return ProfileStatsSection(stats: stats, canOpenGoals: false);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FriendshipActionBar extends ConsumerWidget {
  const _FriendshipActionBar({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(friendshipStatusProvider(userId));

    return statusAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (status) {
        if (status == FriendshipStatus.self) return const SizedBox.shrink();

        return switch (status) {
          FriendshipStatus.friends => OutlinedButton.icon(
              onPressed: () => _removeFriend(context, ref),
              icon: const Icon(Icons.person_remove_outlined, size: 18),
              label: const Text('Remove friend'),
            ),
          FriendshipStatus.pendingOutgoing => OutlinedButton(
              onPressed: null,
              child: const Text('Request pending'),
            ),
          FriendshipStatus.pendingIncoming => Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _respondIncoming(context, ref, false),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _respondIncoming(context, ref, true),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          FriendshipStatus.none => FilledButton.icon(
              onPressed: () => _sendRequest(context, ref),
              icon: const Icon(Icons.person_add_outlined, size: 18),
              label: const Text('Add friend'),
            ),
          FriendshipStatus.self => const SizedBox.shrink(),
        };
      },
    );
  }

  Future<void> _sendRequest(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(connectionsRepositoryProvider).sendFriendRequest(userId);
      invalidateConnectionData(ref);
      ref.invalidate(friendshipStatusProvider(userId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toUserMessage())),
        );
      }
    }
  }

  Future<void> _respondIncoming(
    BuildContext context,
    WidgetRef ref,
    bool accept,
  ) async {
    final requests = await ref.read(connectionsRepositoryProvider).listFriendRequests();
    final incoming = requests.where(
      (r) => r.isIncoming && r.requesterId == userId,
    );
    if (incoming.isEmpty) return;

    try {
      await ref.read(connectionsRepositoryProvider).respondFriendRequest(
            requestId: incoming.first.id,
            accept: accept,
          );
      invalidateConnectionData(ref);
      ref.invalidate(friendshipStatusProvider(userId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'You are now friends' : 'Request declined'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toUserMessage())),
        );
      }
    }
  }

  Future<void> _removeFriend(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(connectionsRepositoryProvider).removeFriend(userId);
      invalidateConnectionData(ref);
      ref.invalidate(friendshipStatusProvider(userId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend removed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toUserMessage())),
        );
      }
    }
  }
}

class _PublicProfileHeader extends StatelessWidget {
  const _PublicProfileHeader({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 32,
          backgroundImage:
              profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
          child: profile.avatarUrl == null
              ? Text(profile.initials, style: const TextStyle(fontSize: 22))
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.publicName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.profileName(context),
              ),
              if (profile.username != null)
                Text(
                  '@${profile.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.primary),
                ),
              if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  profile.bio!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (profile.location != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        profile.location!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
