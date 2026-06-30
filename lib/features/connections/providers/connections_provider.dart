import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/friend_connection.dart';
import '../../auth/providers/auth_provider.dart';
import '../../feed/providers/feed_provider.dart';
import '../data/connections_repository.dart';

final connectionsRepositoryProvider = Provider<ConnectionsRepository>((ref) {
  return ConnectionsRepository(ref.watch(supabaseClientProvider));
});

final myFriendsProvider = FutureProvider<List<FriendConnection>>((ref) {
  return ref.watch(connectionsRepositoryProvider).listMyFriends();
});

final friendIdsProvider = Provider<AsyncValue<Set<String>>>((ref) {
  return ref.watch(myFriendsProvider).whenData(
        (friends) => friends.map((f) => f.friendId).toSet(),
      );
});

final friendRequestsProvider = FutureProvider<List<FriendRequest>>((ref) {
  return ref.watch(connectionsRepositoryProvider).listFriendRequests();
});

final incomingFriendRequestsProvider = Provider<AsyncValue<List<FriendRequest>>>((ref) {
  return ref.watch(friendRequestsProvider).whenData(
        (requests) => requests.where((r) => r.isIncoming).toList(),
      );
});

final friendshipStatusProvider =
    FutureProvider.family<FriendshipStatus, String>((ref, userId) {
  return ref.watch(connectionsRepositoryProvider).getFriendshipStatus(userId);
});

void invalidateConnectionData(WidgetRef ref) {
  ref.invalidate(myFriendsProvider);
  ref.invalidate(friendRequestsProvider);
  ref.invalidate(feedProvider);
}

void invalidateConnectionDataFromRef(Ref ref) {
  ref.invalidate(myFriendsProvider);
  ref.invalidate(friendRequestsProvider);
  ref.invalidate(feedProvider);
}
