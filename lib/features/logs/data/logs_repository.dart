import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/log.dart';

class LogsRepository {
  LogsRepository(this._client);

  final SupabaseClient _client;

  Future<List<LogEntry>> getLogsForGoal(String goalId) async {
    final data = await _client
        .from('logs')
        .select('*, profiles(display_name, avatar_url)')
        .eq('user_goal_id', goalId)
        .order('log_date', ascending: false);
    return (data as List).map((e) => LogEntry.fromJson(e)).toList();
  }

  Future<List<LogEntry>> getMyLogsForGoal(String goalId, String userId) async {
    final data = await _client
        .from('logs')
        .select('*, profiles(display_name, avatar_url)')
        .eq('user_goal_id', goalId)
        .eq('author_id', userId)
        .order('log_date', ascending: false);
    return (data as List).map((e) => LogEntry.fromJson(e)).toList();
  }

  Future<LogEntry> createLog(LogEntry log) async {
    final data = await _client
        .from('logs')
        .insert(log.toInsertJson())
        .select('*, profiles(display_name, avatar_url)')
        .single();
    return LogEntry.fromJson(data);
  }

  Future<LogEntry?> getTodayLog(String goalId, String userId) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final data = await _client
        .from('logs')
        .select('*, profiles(display_name, avatar_url)')
        .eq('user_goal_id', goalId)
        .eq('author_id', userId)
        .eq('log_date', today)
        .maybeSingle();
    if (data == null) return null;
    return LogEntry.fromJson(data);
  }

  Future<bool> everyoneLoggedToday(String goalId) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final members = await _client
        .from('goal_memberships')
        .select('user_id')
        .eq('user_goal_id', goalId);
    final memberIds = (members as List).map((m) => m['user_id'] as String).toList();

    if (memberIds.isEmpty) return false;

    final logs = await _client
        .from('logs')
        .select('author_id')
        .eq('user_goal_id', goalId)
        .eq('log_date', today);

    final loggedIds = (logs as List).map((l) => l['author_id'] as String).toSet();
    return memberIds.every(loggedIds.contains);
  }
}
