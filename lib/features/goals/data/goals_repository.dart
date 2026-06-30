import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/connectivity_provider.dart';
import '../../../core/offline/offline_cache.dart';
import '../../../core/offline/offline_fetch.dart';
import '../../../core/offline/offline_write_exception.dart';
import '../../../shared/utils/json_utils.dart';
import '../../../shared/utils/supabase_embeds.dart';
import '../../../shared/models/goal_group.dart';
import '../../../shared/models/goal_invite.dart';
import '../../../shared/models/goal_membership.dart';
import '../../../shared/models/goal_template.dart';
import '../../../shared/models/group_invite.dart';
import '../../../shared/models/group_membership.dart';
import '../../../shared/models/invitable_user.dart';
import '../../../shared/models/user_goal.dart';

class GoalsRepository {
  GoalsRepository(
    this._client,
    this._cache,
    this._connectivity,
  );

  final SupabaseClient _client;
  final OfflineCache _cache;
  final OnlineChecker _connectivity;

  Future<void> _requireOnline() async {
    if (!await _connectivity.checkOnline()) {
      throw const OfflineWriteException();
    }
  }

  Map<String, dynamic> _userGoalToCacheJson(UserGoal goal) {
    return {
      'id': goal.id,
      'template_id': goal.templateId,
      'owner_id': goal.ownerId,
      'title': goal.title,
      'description': goal.description,
      'mode': goal.mode,
      'cadence': goal.cadence,
      'cadence_interval_days': goal.cadenceIntervalDays,
      'metric_type': goal.metricType,
      'metric_unit': goal.metricUnit,
      'target_value': goal.targetValue,
      'start_value': goal.startValue,
      'target_date': goal.targetDate?.toIso8601String().split('T').first,
      'status': goal.status,
      'created_at': goal.createdAt.toIso8601String(),
      'group_id': goal.groupId,
      if (goal.groupName != null) 'groups': {'name': goal.groupName},
    };
  }

  Future<List<GoalTemplate>> getTemplates({String? category}) async {
    var query = _client.from('goal_templates').select();
    if (category != null && category != 'all') {
      query = query.eq('category', category);
    }
    final data = await query.order('title');
    return asJsonList(data).map((e) => GoalTemplate.fromJson(e)).toList();
  }

  Future<List<UserGoal>> getMyGoals(String userId) {
    return fetchListWithCache(
      cache: _cache,
      cacheKey: 'my_goals_$userId',
      emptyMessage: 'No cached goals. Connect to the internet and refresh.',
      fetchRows: () async {
        final goals = await _fetchMyGoalsFromNetwork(userId);
        return goals.map(_userGoalToCacheJson).toList();
      },
      parse: UserGoal.fromJson,
    );
  }

  Future<List<UserGoal>> _fetchMyGoalsFromNetwork(String userId) async {
    final memberships = await _client
        .from('goal_memberships')
        .select('user_goal_id')
        .eq('user_id', userId);

    final directGoalIds = asJsonList(memberships)
        .map((m) => m['user_goal_id'] as String)
        .toSet();

    final groupMemberships = await _client
        .from('group_memberships')
        .select('group_id')
        .eq('user_id', userId);

    final groupIds = asJsonList(groupMemberships)
        .map((m) => m['group_id'] as String)
        .toList();

    final goals = <UserGoal>[];
    final seen = <String>{};

    if (directGoalIds.isNotEmpty) {
      final data = await _client
          .from('user_goals')
          .select('*, groups(name)')
          .inFilter('id', directGoalIds.toList())
          .eq('status', 'active')
          .order('created_at', ascending: false);
      for (final row in asJsonList(data)) {
        final goal = UserGoal.fromJson(row);
        if (seen.add(goal.id)) goals.add(goal);
      }
    }

    if (groupIds.isNotEmpty) {
      final data = await _client
          .from('user_goals')
          .select('*, groups(name)')
          .inFilter('group_id', groupIds)
          .eq('status', 'active')
          .order('created_at', ascending: false);
      for (final row in asJsonList(data)) {
        final goal = UserGoal.fromJson(row);
        if (seen.add(goal.id)) goals.add(goal);
      }
    }

    goals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return goals;
  }

  Future<List<GoalGroup>> getMyGroups(String userId) async {
    final memberships = await _client
        .from('group_memberships')
        .select('group_id')
        .eq('user_id', userId);

    final groupIds = asJsonList(memberships)
        .map((m) => m['group_id'] as String)
        .toList();

    if (groupIds.isEmpty) return [];

    final data = await _client
        .from('groups')
        .select('*, user_goals(id)')
        .inFilter('id', groupIds)
        .order('created_at', ascending: false);

    return asJsonList(data).map((e) => GoalGroup.fromJson(e)).toList();
  }

  Future<GoalGroup> getGroup(String groupId) async {
    final data = await _client
        .from('groups')
        .select('*, user_goals(id)')
        .eq('id', groupId)
        .single();
    return GoalGroup.fromJson(data);
  }

  Future<List<UserGoal>> getGoalsInGroup(String groupId) async {
    final data = await _client
        .from('user_goals')
        .select('*, groups(name)')
        .eq('group_id', groupId)
        .eq('status', 'active')
        .order('created_at', ascending: false);
    return asJsonList(data).map((e) => UserGoal.fromJson(e)).toList();
  }

  Future<GoalGroup> createGroup({
    required String ownerId,
    required String name,
    String? description,
  }) async {
    await _requireOnline();
    final data = await _client.rpc(
      'create_group',
      params: {
        'p_name': name.trim(),
        'p_description': description?.trim(),
      },
    );
    return GoalGroup.fromJson(asJsonMap(data));
  }

  Future<UserGoal> createGoal(UserGoal goal) async {
    await _requireOnline();
    final payload = goal.toInsertJson();
    final data = await _client.rpc('create_user_goal', params: {'p_goal': payload});
    final created = UserGoal.fromJson(asJsonMap(data));

    if (goal.groupId != null) {
      final withGroup = await _client
          .from('user_goals')
          .select('*, groups(name)')
          .eq('id', created.id)
          .maybeSingle();
      if (withGroup != null) return UserGoal.fromJson(asJsonMap(withGroup));
    }

    return created;
  }

  Future<UserGoal> updateGoal(UserGoal goal) async {
    await _requireOnline();
    final data = await _client.rpc(
      'update_user_goal',
      params: {
        'p_goal_id': goal.id,
        'p_goal': goal.toUpdateJson(),
      },
    );
    return UserGoal.fromJson(asJsonMap(data));
  }

  Future<UserGoal> getGoal(String goalId) {
    return fetchObjectWithCache(
      cache: _cache,
      cacheKey: 'goal_$goalId',
      emptyMessage: 'This goal is not available offline yet.',
      fetchRow: () async {
        final data = await _client
            .from('user_goals')
            .select('*, groups(name)')
            .eq('id', goalId)
            .single();
        return asJsonMap(data);
      },
      parse: UserGoal.fromJson,
    );
  }

  Future<List<GoalMembership>> getMembers(String goalId) async {
    final goal = await getGoal(goalId);
    if (goal.groupId != null) {
      return getGroupMembersAsGoalMemberships(goal.groupId!);
    }

    final data = await _client
        .from('goal_memberships')
        .select(SupabaseEmbeds.membershipWithUser)
        .eq('user_goal_id', goalId)
        .order('joined_at');
    return asJsonList(data).map((e) => GoalMembership.fromJson(e)).toList();
  }

  Future<List<GroupMembership>> getGroupMembers(String groupId) async {
    final data = await _client
        .from('group_memberships')
        .select(SupabaseEmbeds.membershipWithUser)
        .eq('group_id', groupId)
        .order('joined_at');
    return asJsonList(data).map((e) => GroupMembership.fromJson(e)).toList();
  }

  Future<List<GoalMembership>> getGroupMembersAsGoalMemberships(String groupId) async {
    final members = await getGroupMembers(groupId);
    return members
        .map(
          (m) => GoalMembership(
            id: m.id,
            userGoalId: '',
            userId: m.userId,
            role: m.role,
            joinedAt: m.joinedAt,
            profile: m.profile,
          ),
        )
        .toList();
  }

  Future<List<GoalInvite>> getPendingInvitesForGoal(String goalId) async {
    final goal = await getGoal(goalId);
    if (goal.groupId != null) {
      final invites = await getPendingInvitesForGroup(goal.groupId!);
      return invites
          .map(
            (i) => GoalInvite(
              id: i.id,
              userGoalId: goalId,
              invitedEmail: i.invitedEmail,
              invitedBy: i.invitedBy,
              status: i.status,
              createdAt: i.createdAt,
              goalTitle: goal.title,
              invitedByName: i.invitedByName,
            ),
          )
          .toList();
    }

    final data = await _client
        .from('goal_invites')
        .select()
        .eq('user_goal_id', goalId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return asJsonList(data).map((e) => GoalInvite.fromJson(e)).toList();
  }

  Future<List<GroupInvite>> getPendingInvitesForGroup(String groupId) async {
    final data = await _client
        .from('group_invites')
        .select()
        .eq('group_id', groupId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return asJsonList(data).map((e) => GroupInvite.fromJson(e)).toList();
  }

  Future<List<GoalInvite>> getMyPendingInvites() async {
    final goalInvites = await _client.rpc('get_my_goal_invites');
    return asJsonList(goalInvites).map((e) => GoalInvite.fromJson(e)).toList();
  }

  Future<List<GroupInvite>> getMyPendingGroupInvites() async {
    final data = await _client.rpc('get_my_group_invites');
    return asJsonList(data).map((e) => GroupInvite.fromJson(e)).toList();
  }

  Future<void> addMember({
    required String goalId,
    required String userId,
  }) async {
    await _client.from('goal_memberships').insert({
      'user_goal_id': goalId,
      'user_id': userId,
      'role': 'member',
    });
  }

  Future<void> addGroupMember({
    required String groupId,
    required String userId,
  }) async {
    await _client.from('group_memberships').insert({
      'group_id': groupId,
      'user_id': userId,
      'role': 'member',
    });
  }

  Future<InviteResult> inviteByEmail({
    required String goalId,
    required String email,
  }) async {
    final goal = await getGoal(goalId);
    if (goal.groupId != null) {
      return inviteGroupByEmail(groupId: goal.groupId!, email: email);
    }

    final data = await _client.rpc(
      'invite_user_to_goal',
      params: {'p_goal_id': goalId, 'p_email': email.trim()},
    );
    return InviteResult.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<InviteResult> inviteGroupByEmail({
    required String groupId,
    required String email,
  }) async {
    final data = await _client.rpc(
      'invite_user_to_group',
      params: {'p_group_id': groupId, 'p_email': email.trim()},
    );
    return InviteResult.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> acceptInvite(String inviteId) async {
    await _client.rpc('accept_goal_invite', params: {'p_invite_id': inviteId});
  }

  Future<void> acceptGroupInvite(String inviteId) async {
    await _client.rpc('accept_group_invite', params: {'p_invite_id': inviteId});
  }

  Future<void> cancelInvite(String inviteId) async {
    await _client
        .from('goal_invites')
        .update({'status': 'cancelled'})
        .eq('id', inviteId);
  }

  Future<void> cancelGroupInvite(String inviteId) async {
    await _client
        .from('group_invites')
        .update({'status': 'cancelled'})
        .eq('id', inviteId);
  }

  Future<void> removeMember({
    required String goalId,
    required String userId,
  }) async {
    final goal = await getGoal(goalId);
    if (goal.groupId != null) {
      await removeGroupMember(groupId: goal.groupId!, userId: userId);
      return;
    }

    await _client
        .from('goal_memberships')
        .delete()
        .eq('user_goal_id', goalId)
        .eq('user_id', userId);
  }

  Future<void> removeGroupMember({
    required String groupId,
    required String userId,
  }) async {
    await _client
        .from('group_memberships')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  Future<void> leaveGroup({
    required String goalId,
    required String userId,
  }) async {
    final goal = await getGoal(goalId);
    if (goal.groupId != null) {
      await leaveGroupById(groupId: goal.groupId!, userId: userId);
      return;
    }
    await removeMember(goalId: goalId, userId: userId);
  }

  Future<void> leaveGroupById({
    required String groupId,
    required String userId,
  }) async {
    await _client
        .from('group_memberships')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  Future<List<InvitableUser>> searchUsersForInvite(String query) async {
    if (query.trim().isEmpty) return [];
    final data = await _client.rpc(
      'search_users_for_invite',
      params: {'search_term': query.trim()},
    );
    return asJsonList(data).map((e) => InvitableUser.fromJson(e)).toList();
  }

  Future<bool> isGoalOwner(String goalId, String userId) async {
    final goal = await getGoal(goalId);
    if (goal.groupId != null) {
      return isGroupOwner(goal.groupId!, userId);
    }

    final data = await _client
        .from('goal_memberships')
        .select('role')
        .eq('user_goal_id', goalId)
        .eq('user_id', userId)
        .maybeSingle();
    return data?['role'] == 'owner';
  }

  Future<bool> isGroupOwner(String groupId, String userId) async {
    final data = await _client
        .from('group_memberships')
        .select('role')
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .maybeSingle();
    return data?['role'] == 'owner';
  }
}
