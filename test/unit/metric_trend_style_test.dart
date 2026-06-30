import 'package:flutter_test/flutter_test.dart';
import 'package:tracketiv/shared/models/feed_item.dart';
import 'package:tracketiv/shared/utils/metric_trend_style.dart';
import 'package:tracketiv/shared/utils/metric_utils.dart';

FeedItem _item({
  required double value,
  required double baseline,
  String? metricType,
  String? metricUnit,
}) {
  return FeedItem(
    logId: 'log',
    createdAt: DateTime(2026, 6, 1),
    logDate: DateTime(2026, 6, 1),
    logValue: value,
    previousLogValue: baseline,
    authorId: 'author',
    goalId: 'goal',
    goalTitle: 'Goal',
    goalMode: 'solo',
    metricType: metricType,
    metricUnit: metricUnit,
  );
}

void main() {
  test('weight: decrease is toward goal (green)', () {
    expect(MetricUtils.isLowerBetter('weight'), isTrue);

    final item = _item(value: 80, baseline: 82, metricType: 'weight', metricUnit: 'kg');
    expect(item.valueTrend, LogValueTrend.down);
    expect(item.isProgressTowardGoal, isTrue);
  });

  test('steps: increase is toward goal (green)', () {
    expect(MetricUtils.isLowerBetter('steps'), isFalse);

    final item = _item(value: 9000, baseline: 8000, metricType: 'steps', metricUnit: 'steps');
    expect(item.valueTrend, LogValueTrend.up);
    expect(item.isProgressTowardGoal, isTrue);
  });

  test('steps: decrease is away from goal (red)', () {
    final item = _item(value: 7000, baseline: 8000, metricType: 'steps', metricUnit: 'steps');
    expect(item.isProgressTowardGoal, isFalse);
  });

  test('weight: increase is away from goal (red)', () {
    final item = _item(value: 84, baseline: 82, metricType: 'weight', metricUnit: 'kg');
    expect(item.isProgressTowardGoal, isFalse);
  });
}
