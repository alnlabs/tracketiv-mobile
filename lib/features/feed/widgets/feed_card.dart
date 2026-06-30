import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/feed_item.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/utils/metric_trend_style.dart';
import '../../social/widgets/log_reaction_bar.dart';

/// Compact tweet-style feed row: avatar, header line, body, actions.
class FeedCard extends StatelessWidget {
  const FeedCard({
    super.key,
    required this.item,
    required this.isMe,
  });

  final FeedItem item;
  final bool isMe;

  static const _avatarRadius = 20.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        InkWell(
          onTap: () => context.push('/feed/posts/${item.logId}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(item: item, isMe: isMe, radius: _avatarRadius),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TweetHeader(item: item, isMe: isMe),
                      const SizedBox(height: 2),
                      _GoalContextLine(item: item),
                      const SizedBox(height: 6),
                      _TweetBody(item: item),
                      const SizedBox(height: 8),
                      LogReactionBar(
                        logId: item.logId,
                        compact: true,
                        trailing: _CommentAction(
                          count: item.commentCount,
                          onTap: () => context.push('/feed/posts/${item.logId}'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.item,
    required this.isMe,
    required this.radius,
  });

  final FeedItem item;
  final bool isMe;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        final authorId = item.authorId;
        if (authorId != null) context.push('/users/$authorId');
      },
      borderRadius: BorderRadius.circular(radius),
      child: CircleAvatar(
        radius: radius,
        backgroundColor:
            isMe ? colorScheme.primaryContainer : colorScheme.surfaceContainerHigh,
        child: Text(
          item.authorInitial,
          style: AppTypography.avatarInitial(large: true),
        ),
      ),
    );
  }
}

class _TweetHeader extends StatelessWidget {
  const _TweetHeader({required this.item, required this.isMe});

  final FeedItem item;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final username = item.authorUsername;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 2,
      children: [
        InkWell(
          onTap: () {
        final authorId = item.authorId;
        if (authorId != null) context.push('/users/$authorId');
      },
          child: Text(
            item.authorName ?? item.authorLabel,
            style: AppTypography.authorName(context),
          ),
        ),
        if (username != null && username.isNotEmpty)
          Text(
            '@$username',
            style: AppTypography.metaMuted(context),
          ),
        if (isMe)
          Text(
            '· You',
            style: AppTypography.metaMuted(context),
          ),
        Text(
          '· ${_timeAgo(item.createdAt)}',
          style: AppTypography.metaMuted(context),
        ),
        if (item.isBackdated)
          Text(
            '· ${DateFormat.MMMd().format(item.logDate)}',
            style: AppTypography.metaMuted(context)?.copyWith(
              color: colorScheme.tertiary,
            ),
          ),
      ],
    );
  }

  static String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 6) return DateFormat.MMMd().format(time);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }
}

class _GoalContextLine extends StatelessWidget {
  const _GoalContextLine({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = item.isGroup ? colorScheme.tertiary : colorScheme.primary;
    final group = item.groupName;

    return InkWell(
      onTap: () => context.push('/goals/${item.goalId}'),
      child: Text(
        [
          item.goalTitle,
          if (group != null) group,
          if (item.isGroup) 'Group' else 'Solo',
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.metaMuted(context)?.copyWith(
          color: accent,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _TweetBody extends StatelessWidget {
  const _TweetBody({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
  final postKind = item.postKind;

    return switch (postKind) {
      FeedPostKind.metric => _MetricTweetBody(item: item),
      FeedPostKind.checkIn => _CheckInTweetBody(),
      FeedPostKind.note => Text(
          item.userFacingNote!,
          style: AppTypography.cardBody(context)?.copyWith(height: 1.4),
        ),
      FeedPostKind.unknown => Text(
          'Posted an update',
          style: AppTypography.cardBody(context),
        ),
    };
  }
}

class _MetricTweetBody extends StatelessWidget {
  const _MetricTweetBody({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final trend = item.valueTrend;
    final trendColor = MetricTrendStyle.colorFor(item);
    final unit = item.formattedUnitLabel;
    final hasComparison = item.hasValueComparison;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 2,
          children: [
            if (hasComparison)
              Icon(_trendIcon(trend), size: 22, color: trendColor),
            Text(
              item.formattedNumber,
              style: AppTypography.cardBodyBold(context)?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: hasComparison ? trendColor : colorScheme.onSurface,
              ),
            ),
            if (unit.isNotEmpty)
              Text(
                unit,
                style: AppTypography.meta(context)?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        if (hasComparison && item.formattedChangeLine != null) ...[
          const SizedBox(height: 2),
          Text(
            '${item.formattedChangeLine} · ${item.formattedBaselineLabel} ${item.formattedBaselineValue}',
            style: AppTypography.metaMuted(context)?.copyWith(
              color: trendColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (item.userFacingNote != null) ...[
          const SizedBox(height: 6),
          Text(
            item.userFacingNote!,
            style: AppTypography.cardBody(context)?.copyWith(height: 1.4),
          ),
        ],
      ],
    );
  }

  IconData _trendIcon(LogValueTrend trend) {
    return switch (trend) {
      LogValueTrend.up => Icons.arrow_drop_up_rounded,
      LogValueTrend.down => Icons.arrow_drop_down_rounded,
      LogValueTrend.flat || LogValueTrend.none => Icons.remove_rounded,
    };
  }
}

class _CheckInTweetBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 6),
        Text(
          'Checked in today',
          style: AppTypography.cardBody(context),
        ),
      ],
    );
  }
}

class _CommentAction extends StatelessWidget {
  const _CommentAction({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: AppTypography.actionCount(context),
            ),
          ],
        ),
      ),
    );
  }
}
