import 'package:flutter_test/flutter_test.dart';
import 'package:tracketiv/shared/models/friend_connection.dart';

void main() {
  test('FriendshipStatus parses server values', () {
    expect(FriendshipStatus.fromString('friends'), FriendshipStatus.friends);
    expect(
      FriendshipStatus.fromString('pending_outgoing'),
      FriendshipStatus.pendingOutgoing,
    );
    expect(
      FriendshipStatus.fromString('pending_incoming'),
      FriendshipStatus.pendingIncoming,
    );
    expect(FriendshipStatus.fromString('self'), FriendshipStatus.self);
    expect(FriendshipStatus.fromString('unknown'), FriendshipStatus.none);
  });

  test('FriendRequest identifies incoming requests', () {
    final request = FriendRequest(
      id: 'req',
      requesterId: 'a',
      addresseeId: 'b',
      requesterName: 'Alice',
      direction: 'incoming',
      createdAt: DateTime(2026, 1, 1),
    );
    expect(request.isIncoming, isTrue);
    expect(request.otherUserLabel, isNotEmpty);
  });
}
