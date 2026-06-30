import 'package:flutter/material.dart';

import '../../../shared/models/feed_item.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/utils/metric_trend_style.dart';

class FeedPostBody extends StatelessWidget {
  const FeedPostBody({
    super.key,
    required this.item,
    this.noteMaxLines,
  });

  final FeedItem item;
  final int? noteMaxLines;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final postKind = item.postKind;

    switch (postKind) {
      case FeedPostKind.metric:
        return FeedMetricValueHighlight(item: item);
      case FeedPostKind.checkIn:
        return Row(
          children: [
            Icon(Icons.check_circle, color: colorScheme.primary, size: 16),
            const SizedBox(width: 6),
            Text(
              'Checked in today',
              style: AppTypography.cardBodyBold(context),
            ),
          ],
        );
      case FeedPostKind.note:
        return Text(
          item.userFacingNote!,
          maxLines: noteMaxLines,
          overflow: noteMaxLines != null ? TextOverflow.ellipsis : null,
          style: AppTypography.cardBody(context),
        );
      case FeedPostKind.unknown:
        return Text(
          'Posted an update',
          style: AppTypography.metaMuted(context),
        );
    }
  }
}

class FeedMetricValueHighlight extends StatelessWidget {
  const FeedMetricValueHighlight({super.key, required this.item});

  final FeedItem item;

  IconData _trendArrow(LogValueTrend trend) {
    switch (trend) {
      case LogValueTrend.up:
        return Icons.arrow_drop_up_rounded;
      case LogValueTrend.down:
        return Icons.arrow_drop_down_rounded;
      case LogValueTrend.flat:
      case LogValueTrend.none:
        return Icons.remove_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final trend = item.valueTrend;
    final trendColor = MetricTrendStyle.colorFor(item);
    final unit = item.formattedUnitLabel;
    final hasComparison = item.hasValueComparison;
    const tabular = [FontFeature.tabularFigures()];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (hasComparison) ...[
              Icon(
                _trendArrow(trend),
                size: 28,
                color: trendColor,
              ),
            ],
            Flexible(
              child: Text(
                item.formattedNumber,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.metricHero(
                  context,
                  color: hasComparison ? trendColor : colorScheme.onSurface,
                )?.copyWith(fontFeatures: tabular),
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                unit,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.metricUnit(context),
              ),
            ],
          ],
        ),
        if (hasComparison) ...[
          const SizedBox(height: 2),
          Text(
            item.formattedChangeLine ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.metricTrend(context, color: trendColor)
                ?.copyWith(fontFeatures: tabular, height: 1.2),
          ),
          const SizedBox(height: 2),
          Text(
            '${item.formattedBaselineLabel} ${item.formattedBaselineValue}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.metricBaseline(context)?.copyWith(fontFeatures: tabular),
          ),
        ],
      ],
    );
  }
}
