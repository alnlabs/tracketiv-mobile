import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/friend_connection.dart';
import '../../../shared/utils/json_utils.dart';

class ConnectionsRepository {
  ConnectionsRepository(this._client);

  final SupabaseClient _client;

  Future<List<FriendConnection>> listMyFriends() async {
    final data = await _client.rpc('list_my_friends');
    return asJsonList(data).map(FriendConnection.fromJson).toList();
  }

  Future<List<FriendRequest>> listFriendRequests() async {
    final data = await _client.rpc('list_friend_requests');
    return asJsonList(data).map(FriendRequest.fromJson).toList();
  }

  Future<FriendshipStatus> getFriendshipStatus(String userId) async {
    final data = await _client.rpc(
      'get_friendship_status',
      params: {'p_user_id': userId},
    );
    return FriendshipStatus.fromString(data as String);
  }

  Future<String> sendFriendRequest(String userId) async {
    final data = await _client.rpc(
      'send_friend_request',
      params: {'p_user_id': userId},
    );
    return data as String;
  }

  Future<void> respondFriendRequest({
    required String requestId,
    required bool accept,
  }) async {
    await _client.rpc(
      'respond_friend_request',
      params: {
        'p_request_id': requestId,
        'p_accept': accept,
      },
    );
  }

  Future<void> removeFriend(String userId) async {
    await _client.rpc('remove_friend', params: {'p_user_id': userId});
  }
}
