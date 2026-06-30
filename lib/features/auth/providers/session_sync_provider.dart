import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../admin/providers/admin_provider.dart';
import '../../connections/providers/connections_provider.dart';
import '../../feed/providers/feed_provider.dart';
import '../../goals/providers/goals_provider.dart';
import '../../profile/providers/profile_provider.dart';
import 'auth_provider.dart';

/// Invalidates user-scoped data when the signed-in account changes.
final sessionDataSyncProvider = Provider<void>((ref) {
  ref.listen(authStateProvider, (previous, next) {
    final prevId = previous?.valueOrNull?.session?.user.id;
    final nextId = next.valueOrNull?.session?.user.id;
    if (prevId == nextId) return;
    invalidateUserSessionDataFromRef(ref);
  });
});

void invalidateUserSessionData(WidgetRef ref) {
  ref.invalidate(currentProfileProvider);
  ref.invalidate(mainSessionIsAdminProvider);
  ref.invalidate(myGoalsProvider);
  ref.invalidate(myGroupsProvider);
  ref.invalidate(myPendingInvitesProvider);
  ref.invalidate(myPendingGroupInvitesProvider);
  ref.invalidate(myFriendsProvider);
  ref.invalidate(friendRequestsProvider);
  ref.invalidate(feedProvider);
}

void invalidateUserSessionDataFromRef(Ref ref) {
  ref.invalidate(currentProfileProvider);
  ref.invalidate(mainSessionIsAdminProvider);
  ref.invalidate(myGoalsProvider);
  ref.invalidate(myGroupsProvider);
  ref.invalidate(myPendingInvitesProvider);
  ref.invalidate(myPendingGroupInvitesProvider);
  ref.invalidate(myFriendsProvider);
  ref.invalidate(friendRequestsProvider);
  ref.invalidate(feedProvider);
}
