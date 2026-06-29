import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/reminder_repository.dart';
import '../../../shared/models/reminder.dart';

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepository(ref.watch(supabaseClientProvider));
});

final goalReminderProvider = FutureProvider.family<Reminder?, String>((ref, goalId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(reminderRepositoryProvider).getReminder(goalId, user.id);
});
