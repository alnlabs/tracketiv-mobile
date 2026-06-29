import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/goal_membership.dart';
import '../../../shared/models/goal_template.dart';
import '../../../shared/models/user_goal.dart';

class GoalsRepository {
  GoalsRepository(this._client);

  final SupabaseClient _client;

  Future<List<GoalTemplate>> getTemplates({String? category}) async {
    var query = _client.from('goal_templates').select();
    if (category != null && category != 'all') {
      query = query.eq('category', category);
    }
    final data = await query.order('title');
    return (data as List).map((e) => GoalTemplate.fromJson(e)).toList();
  }

  Future<List<UserGoal>> getMyGoals(String userId) async {
    final memberships = await _client
        .from('goal_memberships')
        .select('user_goal_id')
        .eq('user_id', userId);

    final goalIds = (memberships as List)
        .map((m) => m['user_goal_id'] as String)
        .toList();

    if (goalIds.isEmpty) return [];

    final data = await _client
        .from('user_goals')
        .select()
        .inFilter('id', goalIds)
        .eq('status', 'active')
        .order('created_at', ascending: false);

    return (data as List).map((e) => UserGoal.fromJson(e)).toList();
  }

  Future<UserGoal> createGoal(UserGoal goal) async {
    final data = await _client
        .from('user_goals')
        .insert(goal.toInsertJson())
        .select()
        .single();
    return UserGoal.fromJson(data);
  }

  Future<UserGoal> getGoal(String goalId) async {
    final data = await _client
        .from('user_goals')
        .select()
        .eq('id', goalId)
        .single();
    return UserGoal.fromJson(data);
  }

  Future<List<GoalMembership>> getMembers(String goalId) async {
    final data = await _client
        .from('goal_memberships')
        .select('*, profiles(display_name, avatar_url)')
        .eq('user_goal_id', goalId);
    return (data as List).map((e) => GoalMembership.fromJson(e)).toList();
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

  Future<List<Map<String, dynamic>>> searchProfiles(String query) async {
    if (query.trim().isEmpty) return [];
    final data = await _client
        .from('profiles')
        .select('id, display_name, avatar_url')
        .ilike('display_name', '%$query%')
        .limit(10);
    return List<Map<String, dynamic>>.from(data as List);
  }
}
