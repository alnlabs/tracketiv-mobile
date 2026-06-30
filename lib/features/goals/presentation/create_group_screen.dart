import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/invitable_user.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/filter_pill.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../../shared/widgets/tracketiv_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/goals_provider.dart';
import 'package:tracketiv/shared/utils/api_error_formatter.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();
  final _emailController = TextEditingController();

  final List<InvitableUser> _selectedUsers = [];
  final List<String> _pendingEmails = [];
  List<InvitableUser> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers() async {
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

  void _selectUser(InvitableUser user) {
    if (_selectedUsers.any((u) => u.id == user.id)) return;
    setState(() {
      _selectedUsers.add(user);
      _searchResults = [];
      _searchController.clear();
    });
  }

  void _addEmail() {
    final email = _emailController.text.trim();
    final error = Validators.email(email);
    if (error != null) return;
    if (_pendingEmails.contains(email.toLowerCase())) return;
    setState(() {
      _pendingEmails.add(email.toLowerCase());
      _emailController.clear();
    });
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final group = await ref.read(goalsRepositoryProvider).createGroup(
            ownerId: user.id,
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
          );

      for (final invitee in _selectedUsers) {
        await ref.read(goalsRepositoryProvider).addGroupMember(
              groupId: group.id,
              userId: invitee.id,
            );
      }
      for (final email in _pendingEmails) {
        await ref.read(goalsRepositoryProvider).inviteGroupByEmail(
              groupId: group.id,
              email: email,
            );
      }

      ref.invalidate(myGroupsProvider);
      if (!mounted) return;
      context.go('/groups/${group.id}');
    } catch (e) {
      setState(() => _error = e.toUserMessage());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TracketivAppBar(title: 'Create group'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Step 1: Name your group and invite friends.\n'
                'Step 2: Add goals for everyone to track together.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  hintText: 'e.g. Fitness Buddies',
                ),
                validator: (v) => Validators.required(v, field: 'Group name'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'What is this group about?',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              Text('Invite members', style: AppTypography.sectionTitle(context)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search by name or email',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onSubmitted: (_) => _searchUsers(),
                    ),
                  ),
                  IconButton(
                    onPressed: _isSearching ? null : _searchUsers,
                    icon: _isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_search),
                  ),
                ],
              ),
              ..._searchResults.map(
                (user) => ListTile(
                  leading: CircleAvatar(child: Text(user.initials)),
                  title: Text(user.label),
                  subtitle: user.subtitle != null ? Text(user.subtitle!) : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _selectUser(user),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        hintText: 'Or invite by email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      onSubmitted: (_) => _addEmail(),
                    ),
                  ),
                  IconButton(onPressed: _addEmail, icon: const Icon(Icons.send)),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._selectedUsers.map(
                    (u) => RemovablePill(
                      icon: Icons.person,
                      label: u.displayName ?? 'User',
                      onRemove: () => setState(() => _selectedUsers.remove(u)),
                    ),
                  ),
                  ..._pendingEmails.map(
                    (email) => RemovablePill(
                      icon: Icons.mail,
                      label: email,
                      onRemove: () => setState(() => _pendingEmails.remove(email)),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              LoadingButton(
                onPressed: _createGroup,
                label: 'Create group',
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
