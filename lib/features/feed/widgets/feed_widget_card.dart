import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/feed_item.dart';
import '../../../shared/models/feed_widget.dart';
import '../../../shared/theme/app_typography.dart';

/// Feed row for add-ons (daily quote, etc.) — distinct from member posts.
class FeedWidgetCard extends StatelessWidget {
  const FeedWidgetCard({super.key, required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final payload = item.widgetPayload;
    if (payload == null) {
      return _WidgetPlaceholderCard(item: item);
    }

    final colorScheme = Theme.of(context).colorScheme;
    final accent = _accentForCategory(payload.category, colorScheme);
    final scopeLabel = _scopeLabel(item);

    return Column(
      children: [
        ColoredBox(
          color: accent.withValues(alpha: 0.07),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: accent.withValues(alpha: 0.18),
                  child: Icon(
                    Icons.format_quote_rounded,
                    size: 22,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Daily quote',
                            style: AppTypography.authorName(context),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Add-on',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$scopeLabel · ${_timeAgo(item.createdAt)}',
                        style: AppTypography.metaMuted(context),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        payload.text,
                        style: AppTypography.cardBody(context)?.copyWith(
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '— ${payload.author}',
                        style: AppTypography.metaMuted(context)?.copyWith(
                          fontStyle: FontStyle.italic,
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

  static String _scopeLabel(FeedItem item) {
    if (item.groupName != null && item.groupName!.isNotEmpty) {
      return item.groupName!;
    }
    if (item.isPersonalWidget) return 'For you';
    return 'Your Feed';
  }

  static String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 6) return DateFormat.MMMd().format(time);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Color _accentForCategory(FeedQuoteCategory category, ColorScheme colorScheme) {
    return switch (category) {
      FeedQuoteCategory.goal => colorScheme.primary,
      FeedQuoteCategory.life => colorScheme.secondary,
      FeedQuoteCategory.community => colorScheme.tertiary,
      FeedQuoteCategory.motivation => colorScheme.primary,
      FeedQuoteCategory.mindfulness => colorScheme.secondary,
      FeedQuoteCategory.success => colorScheme.tertiary,
    };
  }
}

class _WidgetPlaceholderCard extends StatelessWidget {
  const _WidgetPlaceholderCard({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(Icons.format_quote_rounded, color: colorScheme.primary),
          ),
          title: const Text('Daily quote'),
          subtitle: const Text('Could not load — pull down to refresh'),
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
