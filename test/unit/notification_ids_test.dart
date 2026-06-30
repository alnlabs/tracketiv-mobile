import 'package:flutter_test/flutter_test.dart';
import 'package:tracketiv/shared/utils/notification_ids.dart';

void main() {
  test('forGoal fits 32-bit and leaves room for day suffix', () {
    const goalId = '8abdcaf2-e13b-47d8-9420-10c4b6328edc';
    final base = NotificationIds.forGoal(goalId);

    expect(base, greaterThanOrEqualTo(0));
    expect(base, lessThan(200000000));
    expect(base * 10 + 7, lessThanOrEqualTo(0x7FFFFFFF));
  });

  test('fromKey and clamp stay within signed 32-bit range', () {
    const uuid = '44341885-1985-4a18-ab57-f2178f076759';
    final id = NotificationIds.fromKey(uuid);
    final epoch = NotificationIds.clamp(DateTime.now().millisecondsSinceEpoch);

    expect(id, inInclusiveRange(0, 0x7FFFFFFF));
    expect(epoch, inInclusiveRange(0, 0x7FFFFFFF));
  });
}
