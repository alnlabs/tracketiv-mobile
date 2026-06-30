import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/utils/scaffold_layout.dart';
import '../../../shared/theme/app_typography.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/goals_provider.dart';
import '../widgets/invite_members_panel.dart';
import '../../../shared/widgets/tracketiv_app_bar.dart';
import 'package:tracketiv/shared/utils/api_error_formatter.dart';

/// Legacy route for per-goal members. Redirects to group members when applicable.
class GoalGroupMembersScreen extends ConsumerWidget {
  const GoalGroupMembersScreen({super.key, required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalAsync = ref.watch(goalDetailProvider(goalId));

    return goalAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text(e.toUserMessage()))),
      data: (goal) {
        if (goal.groupId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.replace('/groups/${goal.groupId}/members');
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final membersAsync = ref.watch(goalMembersProvider(goalId));
        final invitesAsync = ref.watch(goalPendingInvitesProvider(goalId));
        final isOwnerAsync = ref.watch(isGoalOwnerProvider(goalId));
        final user = ref.watch(currentUserProvider);

        return Scaffold(
          appBar: const TracketivAppBar(title: 'Group members'),
          body: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              listScrollBottomPadding(context),
            ),
            children: [
              isOwnerAsync.when(
                data: (isOwner) {
                  if (!isOwner) return const SizedBox.shrink();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: InviteMembersPanel(
                        goalId: goalId,
                        onInvited: () {
                          ref.invalidate(goalMembersProvider(goalId));
                          ref.invalidate(goalPendingInvitesProvider(goalId));
                        },
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              Text('Members', style: AppTypography.sectionTitle(context)),
              membersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(e.toUserMessage()),
                data: (members) => Column(
                  children: members.map((member) {
                    final isMe = member.userId == user?.id;
                    return Card(
                      child: ListTile(
                        onTap: () => context.push('/users/${member.userId}'),
                        leading: CircleAvatar(
                          child: Text((member.displayName ?? 'U')[0].toUpperCase()),
                        ),
                        title: Text(member.publicLabel),
                        subtitle: Text(member.role == 'owner' ? 'Owner' : 'Member'),
                        trailing: isMe && member.role != 'owner'
                            ? TextButton(
                                onPressed: () async {
                                  await ref.read(goalsRepositoryProvider).leaveGroup(
                                        goalId: goalId,
                                        userId: user!.id,
                                      );
                                  ref.invalidate(myGoalsProvider);
                                  if (context.mounted) context.go('/home');
                                },
                                child: const Text('Leave'),
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
              invitesAsync.when(
                data: (invites) {
                  if (invites.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text('Pending invites', style: AppTypography.sectionTitle(context)),
                      ...invites.map(
                        (invite) => ListTile(
                          leading: const Icon(Icons.mail_outline),
                          title: Text(invite.invitedEmail),
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
        );
      },
    );
  }
}
