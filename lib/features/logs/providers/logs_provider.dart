import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/logs_repository.dart';
import '../../../shared/models/log.dart';

final logsRepositoryProvider = Provider<LogsRepository>((ref) {
  return LogsRepository(ref.watch(supabaseClientProvider));
});

final goalLogsProvider = FutureProvider.family<List<LogEntry>, String>((ref, goalId) {
  return ref.watch(logsRepositoryProvider).getLogsForGoal(goalId);
});

final myGoalLogsProvider = FutureProvider.family<List<LogEntry>, String>((ref, goalId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.watch(logsRepositoryProvider).getMyLogsForGoal(goalId, user.id);
});

final everyoneLoggedTodayProvider = FutureProvider.family<bool, String>((ref, goalId) {
  return ref.watch(logsRepositoryProvider).everyoneLoggedToday(goalId);
});
