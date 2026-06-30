import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/device_token_repository.dart';
import '../services/push_notification_service.dart';
import '../../reminders/services/notification_service.dart';

final deviceTokenRepositoryProvider = Provider<DeviceTokenRepository>((ref) {
  return DeviceTokenRepository(ref.watch(supabaseClientProvider));
});

/// Registers FCM token when a user session is active.
final pushRegistrationProvider = Provider<void>((ref) {
  if (kIsWeb) return;

  final user = ref.watch(currentUserProvider);
  if (user == null) return;

  ref.listen(authStateProvider, (previous, next) async {
    final hadSession = previous?.valueOrNull?.session != null;
    final hasSession = next.valueOrNull?.session != null;

    if (!hadSession && hasSession) {
      await PushNotificationService.instance.registerForUser();
    } else if (hadSession && !hasSession) {
      await PushNotificationService.instance.unregister();
    }
  });

  Future.microtask(PushNotificationService.instance.registerForUser);
});

bool _pushNavigationConfigured = false;

void configurePushNotificationNavigation(GoRouter router) {
  if (_pushNavigationConfigured) return;
  _pushNavigationConfigured = true;

  PushNotificationService.instance.onNotificationTap = (data) {
    final goalId = data['goal_id'] as String?;
    final logId = data['log_id'] as String?;
    final groupId = data['group_id'] as String?;
    final type = data['type'] as String?;

    if (logId != null &&
        (type == 'reaction' ||
            type == 'comment' ||
            type == 'group_post' ||
            type == 'group_reaction' ||
            type == 'group_comment')) {
      router.go('/feed/posts/$logId');
      return;
    }

    if (goalId != null &&
        (type == 'reaction' ||
            type == 'comment' ||
            type == 'goal_invite' ||
            type == 'group_post' ||
            type == 'group_reaction' ||
            type == 'group_comment')) {
      router.go('/goals/$goalId');
      return;
    }

    if (groupId != null && type == 'group_invite') {
      router.go('/groups/$groupId');
      return;
    }

    router.go('/notifications');
  };
}

void configureLocalReminderNavigation(GoRouter router) {
  NotificationService.instance.configureReminderNavigation((goalId) {
    router.push('/goals/$goalId/log');
  });
}
