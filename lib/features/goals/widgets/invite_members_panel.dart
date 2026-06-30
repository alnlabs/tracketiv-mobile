import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/invitable_user.dart';
import '../../../shared/models/goal_invite.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/theme/app_typography.dart';
import '../providers/goals_provider.dart';
import 'package:tracketiv/shared/utils/api_error_formatter.dart';

class InviteMembersPanel extends ConsumerStatefulWidget {
  const InviteMembersPanel({
    super.key,
    this.goalId,
    this.groupId,
    this.onInvited,
  }) : assert(goalId != null || groupId != null, 'Provide goalId or groupId');

  final String? goalId;
  final String? groupId;
  final VoidCallback? onInvited;

  @override
  ConsumerState<InviteMembersPanel> createState() => _InviteMembersPanelState();
}

class _InviteMembersPanelState extends ConsumerState<InviteMembersPanel> {
  final _searchController = TextEditingController();
  final _emailController = TextEditingController();
  List<InvitableUser> _searchResults = [];
  bool _isSearching = false;
  bool _isInviting = false;

  @override
  void dispose() {
    _searchController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final results = await ref.read(goalsRepositoryProvider).searchUsersForInvite(query);
      setState(() => _searchResults = results);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _addUser(InvitableUser user) async {
    setState(() => _isInviting = true);
    try {
      final repo = ref.read(goalsRepositoryProvider);
      if (widget.groupId != null) {
        await repo.addGroupMember(groupId: widget.groupId!, userId: user.id);
        ref.invalidate(groupMembersProvider(widget.groupId!));
      } else {
        await repo.addMember(goalId: widget.goalId!, userId: user.id);
        ref.invalidate(goalMembersProvider(widget.goalId!));
      }
      widget.onInvited?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.displayName ?? 'User'} joined the group')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toUserMessage())),
        );
      }
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  Future<void> _inviteByEmail() async {
    final email = _emailController.text.trim();
    final error = Validators.email(email);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _isInviting = true);
    try {
      final repo = ref.read(goalsRepositoryProvider);
      final InviteResult result;
      if (widget.groupId != null) {
        result = await repo.inviteGroupByEmail(groupId: widget.groupId!, email: email);
        ref.invalidate(groupMembersProvider(widget.groupId!));
        ref.invalidate(groupPendingInvitesProvider(widget.groupId!));
      } else {
        result = await repo.inviteByEmail(goalId: widget.goalId!, email: email);
        ref.invalidate(goalMembersProvider(widget.goalId!));
        ref.invalidate(goalPendingInvitesProvider(widget.goalId!));
      }
      _emailController.clear();
      widget.onInvited?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toUserMessage())),
        );
      }
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Grow your group',
          style: AppTypography.cardTitle(context, weight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Search existing users or send an email invite.',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search by name or @username',
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 20),
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
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    onPressed: _search,
                  ),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
        ),
        if (_searchResults.isNotEmpty) ...[
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < _searchResults.length; i++) ...[
                  _SearchResultRow(
                    user: _searchResults[i],
                    isInviting: _isInviting,
                    onAdd: () => _addUser(_searchResults[i]),
                  ),
                  if (i < _searchResults.length - 1)
                    Divider(
                      height: 1,
                      indent: 52,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Invite by email',
          style: AppTypography.sectionTitle(context),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  hintText: 'friend@email.com',
                  isDense: true,
                  prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _inviteByEmail(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _isInviting ? null : _inviteByEmail,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Send'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({
    required this.user,
    required this.isInviting,
    required this.onAdd,
  });

  final InvitableUser user;
  final bool isInviting;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.primaryContainer,
            backgroundImage:
                user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
            child: user.avatarUrl == null
                ? Text(user.initials, style: AppTypography.avatarInitial())
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cardTitle(context, weight: FontWeight.w600),
                ),
                if (user.subtitle != null)
                  Text(
                    user.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: isInviting ? null : onAdd,
            icon: const Icon(Icons.person_add_outlined, size: 20),
            tooltip: 'Add to group',
          ),
        ],
      ),
    );
  }
}
