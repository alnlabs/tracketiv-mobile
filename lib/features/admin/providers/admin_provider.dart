import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/admin_repository.dart';
import 'admin_auth_provider.dart';
import 'admin_session_provider.dart';
import '../../../shared/models/admin_dashboard_stats.dart';
import '../../../shared/models/crash_report.dart';
import '../../../shared/models/admin_table.dart';
import '../../../shared/models/admin_user.dart';
import '../../../shared/models/app_config.dart';
import '../../../shared/models/feedback_item.dart';
import '../../../shared/models/goal_template.dart';
import '../../profile/providers/profile_provider.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(supabaseClientProvider));
});

final adminDashboardProvider = FutureProvider<AdminDashboardStats>((ref) {
  return ref.watch(adminRepositoryProvider).getDashboard();
});

final adminUsersProvider = FutureProvider.family<List<AdminUser>, bool>((ref, includeDeleted) {
  return ref.watch(adminRepositoryProvider).getUsers(includeDeleted: includeDeleted);
});

final adminConfigProvider = FutureProvider<AppConfig>((ref) {
  return ref.watch(adminRepositoryProvider).getAppConfig();
});

final adminTemplatesProvider = FutureProvider<List<GoalTemplate>>((ref) {
  return ref.watch(adminRepositoryProvider).getAllTemplates();
});

final adminFeedbackProvider = FutureProvider<List<FeedbackItem>>((ref) {
  return ref.watch(adminRepositoryProvider).getAllFeedback();
});

final adminCrashesProvider = FutureProvider<List<CrashReport>>((ref) {
  return ref.watch(adminRepositoryProvider).getCrashReports();
});

final adminRecordsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, AdminRecordsQuery>((ref, query) {
  return ref.watch(adminRepositoryProvider).listRecords(query);
});

/// True when the main app session belongs to an admin account.
final mainSessionIsAdminProvider = FutureProvider<bool>((ref) async {
  final adminMode = ref.watch(adminSessionActiveProvider).valueOrNull ?? false;
  if (adminMode) return false;
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  final profile = await ref.read(profileRepositoryProvider).getProfile(user.id);
  return profile?.isAdmin ?? false;
});
