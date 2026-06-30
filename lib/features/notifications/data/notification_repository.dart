import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/app_notification.dart';

class NotificationRepository {
  NotificationRepository(this._client);

  final SupabaseClient _client;

  Future<List<AppNotification>> getNotifications({int limit = 50}) async {
    final data = await _client
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> getUnreadCount() async {
    final count = await _client.rpc('get_unread_notification_count');
    return count as int? ?? 0;
  }

  Future<void> markRead(String notificationId) async {
    await _client.rpc('mark_notification_read', params: {
      'p_notification_id': notificationId,
    });
  }

  Future<void> markAllRead() async {
    await _client.rpc('mark_all_notifications_read');
  }
}
