import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../../push/services/push_notification_service.dart';
import '../../reminders/services/notification_service.dart';
import '../data/notification_repository.dart';
import '../../../shared/models/app_notification.dart';
import '../../../shared/utils/notification_ids.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(supabaseClientProvider));
});

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) {
  return ref.watch(notificationRepositoryProvider).getNotifications();
});

final unreadNotificationCountProvider = FutureProvider<int>((ref) {
  return ref.watch(notificationRepositoryProvider).getUnreadCount();
});

/// Subscribes to new notifications and refreshes providers + local push on mobile.
final notificationRealtimeProvider = Provider<void>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return;

  final client = ref.watch(supabaseClientProvider);
  final channel = client
      .channel('notifications-${user.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: user.id,
        ),
        callback: (payload) {
          ref.invalidate(notificationsProvider);
          ref.invalidate(unreadNotificationCountProvider);

          if (kIsWeb) return;
          if (PushNotificationService.instance.isEnabled) return;
          final record = payload.newRecord;
          final title = record['title'] as String?;
          final body = record['body'] as String?;
          if (title != null && body != null) {
            final id = record['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
            unawaited(
              NotificationService.instance.showInstant(
                id: NotificationIds.fromKey(id),
                title: title,
                body: body,
              ),
            );
          }
        },
      )
      .subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});
