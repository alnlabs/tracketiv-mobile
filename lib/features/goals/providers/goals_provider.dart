import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../../core/offline/offline_provider.dart';
import '../../../core/offline/connectivity_provider.dart';
import '../data/goals_repository.dart';
import '../../../shared/models/goal_group.dart';
import '../../../shared/models/goal_invite.dart';
import '../../../shared/models/goal_template.dart';
import '../../../shared/models/group_invite.dart';
import '../../../shared/models/group_membership.dart';
import '../../../shared/models/user_goal.dart';
import '../../../shared/models/goal_membership.dart';

final goalsRepositoryProvider = Provider<GoalsRepository>((ref) {
  return GoalsRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(offlineCacheProvider),
    ref.watch(connectivityServiceProvider),
  );
});

final goalTemplatesProvider = FutureProvider.family<List<GoalTemplate>, String?>((ref, category) {
  return ref.watch(goalsRepositoryProvider).getTemplates(category: category);
});

final myGoalsProvider = FutureProvider<List<UserGoal>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Future.value([]);
  return ref.watch(goalsRepositoryProvider).getMyGoals(user.id);
});

/// Goals list without blocking on [myGoalsProvider] loading (empty until loaded).
final myGoalsListProvider = Provider<List<UserGoal>>((ref) {
  return ref.watch(myGoalsProvider).valueOrNull ?? const [];
});

final myGroupsProvider = FutureProvider<List<GoalGroup>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Future.value([]);
  return ref.watch(goalsRepositoryProvider).getMyGroups(user.id);
});

final groupDetailProvider = FutureProvider.family<GoalGroup, String>((ref, groupId) {
  return ref.watch(goalsRepositoryProvider).getGroup(groupId);
});

final groupGoalsProvider = FutureProvider.family<List<UserGoal>, String>((ref, groupId) {
  return ref.watch(goalsRepositoryProvider).getGoalsInGroup(groupId);
});

final groupMembersProvider = FutureProvider.family<List<GroupMembership>, String>((ref, groupId) {
  return ref.watch(goalsRepositoryProvider).getGroupMembers(groupId);
});

final groupPendingInvitesProvider = FutureProvider.family<List<GroupInvite>, String>((ref, groupId) {
  return ref.watch(goalsRepositoryProvider).getPendingInvitesForGroup(groupId);
});

final isGroupOwnerProvider = FutureProvider.family<bool, String>((ref, groupId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  return ref.watch(goalsRepositoryProvider).isGroupOwner(groupId, user.id);
});

final goalDetailProvider = FutureProvider.family<UserGoal, String>((ref, goalId) {
  return ref.watch(goalsRepositoryProvider).getGoal(goalId);
});

final goalMembersProvider = FutureProvider.family<List<GoalMembership>, String>((ref, goalId) {
  return ref.watch(goalsRepositoryProvider).getMembers(goalId);
});

final goalPendingInvitesProvider = FutureProvider.family<List<GoalInvite>, String>((ref, goalId) {
  return ref.watch(goalsRepositoryProvider).getPendingInvitesForGoal(goalId);
});

final myPendingInvitesProvider = FutureProvider<List<GoalInvite>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Future.value([]);
  return ref.watch(goalsRepositoryProvider).getMyPendingInvites();
});

final myPendingGroupInvitesProvider = FutureProvider<List<GroupInvite>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Future.value([]);
  return ref.watch(goalsRepositoryProvider).getMyPendingGroupInvites();
});

final isGoalOwnerProvider = FutureProvider.family<bool, String>((ref, goalId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  return ref.watch(goalsRepositoryProvider).isGoalOwner(goalId, user.id);
});
