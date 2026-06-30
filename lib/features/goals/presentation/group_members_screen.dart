import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/group_membership.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/utils/scaffold_layout.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/tracketiv_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/goals_provider.dart';
import '../widgets/invite_members_panel.dart';

class GroupMembersScreen extends ConsumerWidget {
  const GroupMembersScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupDetailProvider(groupId));
    final membersAsync = ref.watch(groupMembersProvider(groupId));
    final invitesAsync = ref.watch(groupPendingInvitesProvider(groupId));
    final isOwnerAsync = ref.watch(isGroupOwnerProvider(groupId));
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: TracketivAppBar(
        titleWidget: groupAsync.maybeWhen(
          data: (g) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Members',
                style: AppTypography.appBarTitle(context),
              ),
              Text(
                g.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          orElse: () => Text('Members', style: AppTypography.appBarTitle(context)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(groupMembersProvider(groupId));
          ref.invalidate(groupPendingInvitesProvider(groupId));
          ref.invalidate(groupDetailProvider(groupId));
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            12,
            12,
            12,
            listScrollBottomPadding(context),
          ),
          children: [
            isOwnerAsync.when(
              data: (isOwner) {
                if (!isOwner) return const SizedBox.shrink();
                return Material(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: InviteMembersPanel(
                      groupId: groupId,
                      onInvited: () {
                        ref.invalidate(groupMembersProvider(groupId));
                        ref.invalidate(groupPendingInvitesProvider(groupId));
                      },
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            membersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorView(error: e),
              data: (members) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${members.length} member${members.length == 1 ? '' : 's'}',
                      style: AppTypography.sectionTitle(context),
                    ),
                    const SizedBox(height: 8),
                    if (members.isEmpty)
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'No members yet. Invite friends to get started.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      )
                    else
                      Card(
                        margin: EdgeInsets.zero,
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (var i = 0; i < members.length; i++)
                              _MemberTile(
                                member: members[i],
                                isMe: members[i].userId == user?.id,
                                trailing: isOwnerAsync.maybeWhen(
                                  data: (owner) {
                                    if (owner && members[i].role != 'owner') {
                                      return IconButton(
                                        icon: const Icon(Icons.person_remove_outlined, size: 20),
                                        tooltip: 'Remove member',
                                        onPressed: () => _removeMember(
                                          context,
                                          ref,
                                          members[i].userId,
                                          members[i].displayName,
                                        ),
                                      );
                                    }
                                    if (members[i].userId == user?.id &&
                                        members[i].role != 'owner') {
                                      return TextButton(
                                        onPressed: () => _leaveGroup(context, ref),
                                        child: const Text('Leave'),
                                      );
                                    }
                                    return null;
                                  },
                                  orElse: () => null,
                                ),
                                onTap: () => context.push('/users/${members[i].userId}'),
                                showDivider: i < members.length - 1,
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            invitesAsync.when(
              data: (invites) {
                if (invites.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      'Pending invites',
                      style: AppTypography.sectionTitle(context),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (var i = 0; i < invites.length; i++)
                            _PendingInviteTile(
                              email: invites[i].invitedEmail,
                              sentAt: invites[i].createdAt,
                              onCancel: isOwnerAsync.maybeWhen(
                                data: (owner) => owner
                                    ? () => _cancelInvite(context, ref, invites[i].id)
                                    : null,
                                orElse: () => null,
                              ),
                              showDivider: i < invites.length - 1,
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeMember(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String? name,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text('Remove ${name ?? 'this user'} from the group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(goalsRepositoryProvider).removeGroupMember(groupId: groupId, userId: userId);
    ref.invalidate(groupMembersProvider(groupId));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member removed')));
    }
  }

  Future<void> _leaveGroup(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave group?'),
        content: const Text('You will lose access to all goals in this group.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(goalsRepositoryProvider).leaveGroupById(groupId: groupId, userId: user.id);
    ref.invalidate(myGroupsProvider);
    ref.invalidate(myGoalsProvider);
    if (context.mounted) {
      context.go('/home');
    }
  }

  Future<void> _cancelInvite(BuildContext context, WidgetRef ref, String inviteId) async {
    await ref.read(goalsRepositoryProvider).cancelGroupInvite(inviteId);
    ref.invalidate(groupPendingInvitesProvider(groupId));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite cancelled')));
    }
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isMe,
    required this.onTap,
    this.trailing,
    this.showDivider = false,
  });

  final GroupMembership member;
  final bool isMe;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool showDivider;

  String? get _avatarUrl => member.profile?['avatar_url'] as String?;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOwner = member.role == 'owner';
    final roleLabel = isOwner ? 'Owner' : 'Member';

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage:
                      _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                  child: _avatarUrl == null
                      ? Text(
                          (member.displayName ?? 'U')[0].toUpperCase(),
                          style: AppTypography.avatarInitial(),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              member.publicLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.cardTitle(
                                context,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isMe)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                'You',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        member.username != null
                            ? '@${member.username} · $roleLabel'
                            : roleLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 52,
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
      ],
    );
  }
}

class _PendingInviteTile extends StatelessWidget {
  const _PendingInviteTile({
    required this.email,
    required this.sentAt,
    this.onCancel,
    this.showDivider = false,
  });

  final String email;
  final DateTime sentAt;
  final VoidCallback? onCancel;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colorScheme.secondaryContainer,
                child: Icon(
                  Icons.mail_outline_rounded,
                  size: 18,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cardTitle(context, weight: FontWeight.w600),
                    ),
                    Text(
                      'Sent ${DateFormat.MMMd().format(sentAt)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (onCancel != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Cancel invite',
                  onPressed: onCancel,
                ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 52,
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
      ],
    );
  }
}
