import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contracts/repository_contracts.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/reminder_repository.dart';
import '../utils/reminder_scheduler.dart';
import '../../../shared/models/reminder.dart';

final reminderRepositoryProvider = Provider<ReminderRepositoryContract>((ref) {
  return ReminderRepository(ref.watch(supabaseClientProvider));
});

final goalReminderProvider = FutureProvider.family<Reminder?, String>((ref, goalId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(reminderRepositoryProvider).getReminder(goalId, user.id);
});

/// Re-schedules all enabled local reminders after login / app start.
final remindersSyncProvider = Provider<void>((ref) {
  if (kIsWeb) return;

  final user = ref.watch(currentUserProvider);
  if (user == null) return;

  Future.microtask(() async {
    try {
      final reminders =
          await ref.read(reminderRepositoryProvider).getEnabledReminders(user.id);
      await ReminderScheduler.syncAll(reminders);
    } catch (_) {
      // Offline or unauthenticated — ignore.
    }
  });
});
