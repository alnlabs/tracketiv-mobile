import 'package:flutter/material.dart';

import '../models/feed_item.dart';
import 'metric_utils.dart';

/// Goal-aware colors for numeric log trends (green = toward goal, red = away).
abstract final class MetricTrendStyle {
  static const towardGoal = Color(0xFF16A34A);
  static const awayFromGoal = Color(0xFFDC2626);
  static const neutral = Color(0xFF6B7280);

  static Color colorFor(FeedItem item) {
    if (!item.hasValueComparison) return neutral;
    return switch (item.valueTrend) {
      LogValueTrend.flat || LogValueTrend.none => neutral,
      LogValueTrend.up || LogValueTrend.down =>
        item.isProgressTowardGoal ? towardGoal : awayFromGoal,
    };
  }
}

extension FeedItemProgressX on FeedItem {
  bool get isProgressTowardGoal {
    final delta = valueDelta;
    if (delta == null || delta == 0) return true;
    if (MetricUtils.isLowerBetter(metricType, metricUnit: metricUnit)) {
      return delta < 0;
    }
    return delta > 0;
  }
}
