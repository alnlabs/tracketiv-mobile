import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/admin_dashboard_stats.dart';
import '../../../shared/models/crash_report.dart';
import '../../../shared/models/admin_table.dart';
import '../../../shared/models/admin_user.dart';
import '../../../shared/models/app_config.dart';
import '../../../shared/models/feedback_item.dart';
import '../../../shared/models/goal_template.dart';
import '../../../shared/utils/json_utils.dart';

class AdminRepository {
  AdminRepository(this._client);

  final SupabaseClient _client;

  Future<AdminDashboardStats> getDashboard() async {
    final data = await _client.rpc('admin_get_dashboard');
    return AdminDashboardStats.fromJson(asJsonMap(data));
  }

  Future<List<AdminUser>> getUsers({bool includeDeleted = false}) async {
    final data = await _client.rpc(
      'admin_list_users',
      params: {
        'p_include_deleted': includeDeleted,
        'p_limit': 100,
      },
    );
    return asJsonList(data).map((e) => AdminUser.fromJson(e)).toList();
  }

  Future<AppConfig> getAppConfig() async {
    final data = await _client.rpc('admin_get_app_config');
    return AppConfig.fromJson(asJsonMap(data));
  }

  Future<List<GoalTemplate>> getAllTemplates({bool includeDeleted = false}) async {
    var query = _client.from('goal_templates').select();
    if (!includeDeleted) {
      query = query.filter('deleted_at', 'is', null);
    }
    final data = await query.order('title');
    return asJsonList(data).map((e) => GoalTemplate.fromJson(e)).toList();
  }

  Future<GoalTemplate> upsertTemplate(GoalTemplate template) async {
    final data = await _client.rpc(
      'admin_upsert_goal_template',
      params: {'p_template': template.toAdminJson()},
    );
    return GoalTemplate.fromJson(asJsonMap(data));
  }

  Future<void> deleteTemplate(String templateId) async {
    await _client.rpc('admin_delete_goal_template', params: {
      'p_template_id': templateId,
    });
  }

  Future<List<CrashReport>> getCrashReports({int limit = 100}) async {
    final data = await _client.rpc(
      'admin_list_crash_reports',
      params: {'p_limit': limit},
    );
    return asJsonList(data).map((e) => CrashReport.fromJson(e)).toList();
  }

  Future<List<FeedbackItem>> getAllFeedback() async {
    final data = await _client.rpc('admin_list_feedback');
    return asJsonList(data).map((e) => FeedbackItem.fromJson(e)).toList();
  }

  Future<List<Map<String, dynamic>>> listRecords(AdminRecordsQuery query) async {
    final data = await _client.rpc(
      'admin_list_records',
      params: {
        'p_table': query.table,
        'p_include_deleted': query.includeDeleted,
        'p_limit': 100,
      },
    );
    return asJsonList(data).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> softDelete(String table, String id) async {
    await _client.rpc('admin_soft_delete', params: {
      'p_table': table,
      'p_id': id,
    });
  }

  Future<void> restore(String table, String id) async {
    await _client.rpc('admin_restore', params: {
      'p_table': table,
      'p_id': id,
    });
  }
}
