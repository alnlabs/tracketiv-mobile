enum FriendshipStatus {
  self,
  none,
  friends,
  pendingOutgoing,
  pendingIncoming;

  static FriendshipStatus fromString(String value) {
    return switch (value) {
      'self' => FriendshipStatus.self,
      'friends' => FriendshipStatus.friends,
      'pending_outgoing' => FriendshipStatus.pendingOutgoing,
      'pending_incoming' => FriendshipStatus.pendingIncoming,
      _ => FriendshipStatus.none,
    };
  }
}

class FriendConnection {
  const FriendConnection({
    required this.friendId,
    this.displayName,
    this.username,
    required this.friendsSince,
  });

  final String friendId;
  final String? displayName;
  final String? username;
  final DateTime friendsSince;

  String get label => displayName ?? (username != null ? '@$username' : 'User');

  factory FriendConnection.fromJson(Map<String, dynamic> json) {
    return FriendConnection(
      friendId: json['friend_id'] as String,
      displayName: json['display_name'] as String?,
      username: json['username'] as String?,
      friendsSince: DateTime.parse(json['friends_since'] as String),
    );
  }
}

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    this.requesterName,
    this.requesterUsername,
    this.addresseeName,
    this.addresseeUsername,
    required this.direction,
    required this.createdAt,
  });

  final String id;
  final String requesterId;
  final String addresseeId;
  final String? requesterName;
  final String? requesterUsername;
  final String? addresseeName;
  final String? addresseeUsername;
  final String direction;
  final DateTime createdAt;

  bool get isIncoming => direction == 'incoming';

  String get otherUserLabel {
    if (isIncoming) {
      return requesterName ?? (requesterUsername != null ? '@$requesterUsername' : 'Someone');
    }
    return addresseeName ?? (addresseeUsername != null ? '@$addresseeUsername' : 'Someone');
  }

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] as String,
      requesterId: json['requester_id'] as String,
      addresseeId: json['addressee_id'] as String,
      requesterName: json['requester_name'] as String?,
      requesterUsername: json['requester_username'] as String?,
      addresseeName: json['addressee_name'] as String?,
      addresseeUsername: json['addressee_username'] as String?,
      direction: json['direction'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
