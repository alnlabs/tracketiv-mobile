import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/goals_repository.dart';
import '../../../shared/models/goal_template.dart';
import '../../../shared/models/user_goal.dart';
import '../../../shared/models/goal_membership.dart';

final goalsRepositoryProvider = Provider<GoalsRepository>((ref) {
  return GoalsRepository(ref.watch(supabaseClientProvider));
});

final goalTemplatesProvider = FutureProvider.family<List<GoalTemplate>, String?>((ref, category) {
  return ref.watch(goalsRepositoryProvider).getTemplates(category: category);
});

final myGoalsProvider = FutureProvider<List<UserGoal>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.watch(goalsRepositoryProvider).getMyGoals(user.id);
});

final goalDetailProvider = FutureProvider.family<UserGoal, String>((ref, goalId) {
  return ref.watch(goalsRepositoryProvider).getGoal(goalId);
});

final goalMembersProvider = FutureProvider.family<List<GoalMembership>, String>((ref, goalId) {
  return ref.watch(goalsRepositoryProvider).getMembers(goalId);
});
