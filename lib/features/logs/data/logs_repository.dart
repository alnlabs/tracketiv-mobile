import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/contracts/repository_contracts.dart';
import '../../../core/offline/connectivity_provider.dart';
import '../../../core/offline/offline_cache.dart';
import '../../../core/offline/offline_fetch.dart';
import '../../../core/offline/offline_write_exception.dart';
import '../../../shared/models/log.dart';
import '../../../shared/utils/supabase_embeds.dart';

class LogsRepository implements LogsRepositoryContract {
  LogsRepository(
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

  Future<List<LogEntry>> getLogsForGoal(String goalId) {
    return fetchListWithCache(
      cache: _cache,
      cacheKey: 'goal_logs_$goalId',
      emptyMessage: 'No cached logs for this goal.',
      fetchRows: () async {
        final data = await _client
            .from('logs')
            .select(SupabaseEmbeds.logWithAuthor)
            .eq('user_goal_id', goalId)
            .order('log_date', ascending: false);
        return (data as List).cast<Map<String, dynamic>>();
      },
      parse: LogEntry.fromJson,
    );
  }

  Future<List<LogEntry>> getMyLogsForGoal(String goalId, String userId) {
    return fetchListWithCache(
      cache: _cache,
      cacheKey: 'my_goal_logs_${goalId}_$userId',
      emptyMessage: 'No cached logs for this goal.',
      fetchRows: () async {
        final data = await _client
            .from('logs')
            .select(SupabaseEmbeds.logWithAuthor)
            .eq('user_goal_id', goalId)
            .eq('author_id', userId)
            .order('log_date', ascending: false);
        return (data as List).cast<Map<String, dynamic>>();
      },
      parse: LogEntry.fromJson,
    );
  }

  /// Creates a log or updates today's existing entry (one log per goal per day).
  Future<void> createLog(LogEntry log) async {
    await _requireOnline();
    final logDate = log.logDateString;
    final existing = await _client
        .from('logs')
        .select('id')
        .eq('user_goal_id', log.userGoalId)
        .eq('author_id', log.authorId)
        .eq('log_date', logDate)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('logs')
          .update(log.toUpdateJson())
          .eq('id', existing['id'] as String);
      return;
    }

    await _client.from('logs').insert(log.toInsertJson());
  }

  Future<bool> hasTodayLog(String goalId, String userId) async {
    final today = LogEntry.formatLogDate(DateTime.now());
    final data = await _client
        .from('logs')
        .select('id')
        .eq('user_goal_id', goalId)
        .eq('author_id', userId)
        .eq('log_date', today)
        .maybeSingle();
    return data != null;
  }

  Future<bool> everyoneLoggedToday(String goalId) async {
    final today = LogEntry.formatLogDate(DateTime.now());

    final goal = await _client
        .from('user_goals')
        .select('group_id')
        .eq('id', goalId)
        .maybeSingle();

    final groupId = goal?['group_id'] as String?;
    final List<dynamic> members;

    if (groupId != null) {
      members = await _client
          .from('group_memberships')
          .select('user_id')
          .eq('group_id', groupId);
    } else {
      members = await _client
          .from('goal_memberships')
          .select('user_id')
          .eq('user_goal_id', goalId);
    }

    final memberIds = members.map((m) => m['user_id'] as String).toList();
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
