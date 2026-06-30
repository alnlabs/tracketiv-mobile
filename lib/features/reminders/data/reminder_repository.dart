import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/contracts/repository_contracts.dart';
import '../../../shared/models/reminder.dart';

class ReminderRepository implements ReminderRepositoryContract {
  ReminderRepository(this._client);

  final SupabaseClient _client;

  Future<Reminder?> getReminder(String goalId, String userId) async {
    final data = await _client
        .from('reminders')
        .select()
        .eq('user_goal_id', goalId)
        .eq('user_id', userId)
        .maybeSingle();
    if (data == null) return null;
    return Reminder.fromJson(data);
  }

  Future<List<Reminder>> getEnabledReminders(String userId) async {
    final data = await _client
        .from('reminders')
        .select('*, user_goals(title, cadence, cadence_interval_days, created_at)')
        .eq('user_id', userId)
        .eq('enabled', true);
    return (data as List).map((e) => Reminder.fromJson(e)).toList();
  }

  Future<Reminder> upsertReminder(Reminder reminder) async {
    final data = await _client
        .from('reminders')
        .upsert(reminder.toJson(), onConflict: 'user_goal_id,user_id')
        .select()
        .single();
    return Reminder.fromJson(data);
  }

  Future<void> deleteReminder(String id) async {
    await _client.from('reminders').delete().eq('id', id);
  }
}
