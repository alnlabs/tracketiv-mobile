import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/utils/reactions.dart';
import '../../../shared/models/app_notification.dart';
import '../../../shared/utils/scaffold_layout.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/tracketiv_app_bar.dart';
import '../../connections/providers/connections_provider.dart';
import '../../feed/providers/feed_provider.dart';
import '../../goals/providers/goals_provider.dart';
import '../providers/notification_provider.dart';
import 'package:tracketiv/shared/utils/api_error_formatter.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationRealtimeProvider);
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: TracketivAppBar(
        title: 'Notifications',
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationRepositoryProvider).markAllRead();
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadNotificationCountProvider);
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e,
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const EmptyState(
              title: 'No notifications',
              subtitle: 'Invites, friends, reactions, and comments show up here.',
              icon: Icons.notifications_none_outlined,
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadNotificationCountProvider);
            },
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                0,
                8,
                0,
                listScrollBottomPadding(context),
              ),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _NotificationTile(notification: notification);
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  IconData get _icon {
    switch (notification.type) {
      case NotificationType.groupInvite:
      case NotificationType.goalInvite:
        return Icons.mail_outline;
      case NotificationType.reaction:
      case NotificationType.groupReaction:
        return Icons.add_reaction_outlined;
      case NotificationType.comment:
      case NotificationType.groupComment:
        return Icons.chat_bubble_outline;
      case NotificationType.groupPost:
        return Icons.dynamic_feed_outlined;
      case NotificationType.friendRequest:
      case NotificationType.friendAccepted:
        return Icons.person_add_outlined;
    }
  }

  String? get _emoji {
    final type = notification.emojiType;
    if (type == null) return null;
    return Reactions.emoji(type);
  }

  Future<void> _handleTap(BuildContext context, WidgetRef ref) async {
    if (!notification.isRead) {
      await ref.read(notificationRepositoryProvider).markRead(notification.id);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);
    }

    if (!context.mounted) return;

    switch (notification.type) {
      case NotificationType.groupInvite:
        context.go('/home');
      case NotificationType.goalInvite:
        context.go('/home');
      case NotificationType.friendRequest:
        context.go('/home/catalog');
      case NotificationType.friendAccepted:
        final actorId = notification.actorId;
        if (actorId != null) {
          context.push('/users/$actorId');
        } else {
          context.go('/home/catalog');
        }
      case NotificationType.reaction:
      case NotificationType.comment:
      case NotificationType.groupPost:
      case NotificationType.groupReaction:
      case NotificationType.groupComment:
        final logId = notification.logId;
        if (logId != null) {
          context.push('/feed/posts/$logId');
          break;
        }
        final goalId = notification.goalId;
        if (goalId != null) {
          context.push('/goals/$goalId');
        }
    }
  }

  Future<void> _acceptInvite(BuildContext context, WidgetRef ref) async {
    final inviteId = notification.inviteId;
    if (inviteId == null) return;

    try {
      if (notification.type == NotificationType.groupInvite) {
        await ref.read(goalsRepositoryProvider).acceptGroupInvite(inviteId);
        ref.invalidate(myPendingGroupInvitesProvider);
        ref.invalidate(myGroupsProvider);
      } else {
        await ref.read(goalsRepositoryProvider).acceptInvite(inviteId);
        ref.invalidate(myPendingInvitesProvider);
      }
      ref.invalidate(myGoalsProvider);
      ref.invalidate(feedProvider);
      await ref.read(notificationRepositoryProvider).markRead(notification.id);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite accepted!')),
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

  Future<void> _acceptFriendRequest(BuildContext context, WidgetRef ref) async {
    final requestId = notification.requestId;
    if (requestId == null) return;

    try {
      await ref.read(connectionsRepositoryProvider).respondFriendRequest(
            requestId: requestId,
            accept: true,
          );
      invalidateConnectionData(ref);
      await ref.read(notificationRepositoryProvider).markRead(notification.id);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request accepted!')),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInvite = notification.type == NotificationType.groupInvite ||
        notification.type == NotificationType.goalInvite;
    final isFriendRequest =
        notification.type == NotificationType.friendRequest;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: notification.isRead
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Theme.of(context).colorScheme.primaryContainer,
        child: _emoji != null
            ? Text(_emoji!, style: const TextStyle(fontSize: 20))
            : Icon(_icon, size: 20),
      ),
      title: Text(
        notification.title,
        style: notification.isRead
            ? null
            : const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notification.body),
          const SizedBox(height: 4),
          Text(
            _timeAgo(notification.createdAt),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
      isThreeLine: true,
      trailing: isFriendRequest && !notification.isRead
          ? FilledButton(
              onPressed: () => _acceptFriendRequest(context, ref),
              child: const Text('Accept'),
            )
          : isInvite && !notification.isRead
          ? FilledButton(
              onPressed: () => _acceptInvite(context, ref),
              child: const Text('Join'),
            )
          : null,
      onTap: () => _handleTap(context, ref),
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 6) return DateFormat.MMMd().format(time);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
