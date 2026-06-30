import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/feed_item.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/utils/scaffold_layout.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/tracketiv_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../social/widgets/comment_section.dart';
import '../../social/widgets/log_reaction_bar.dart';
import '../providers/feed_provider.dart';
import '../widgets/feed_post_body.dart';

class FeedPostDetailScreen extends ConsumerWidget {
  const FeedPostDetailScreen({super.key, required this.logId});

  final String logId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(feedPostProvider(logId));
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: TracketivAppBar(
        title: 'Post',
        actions: [
          postAsync.maybeWhen(
            data: (item) {
              if (item == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.flag_outlined),
                tooltip: 'View goal',
                onPressed: () => context.push('/goals/${item.goalId}'),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: postAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(feedPostProvider(logId)),
        ),
        data: (item) {
          if (item == null) {
            return ErrorView(
              message: 'Post not found or you do not have access.',
              onRetry: () => ref.invalidate(feedPostProvider(logId)),
            );
          }

          final isMe = item.authorId == user?.id;
          final postKind = item.postKind;
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(feedPostProvider(logId));
              ref.invalidate(feedProvider);
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                listScrollBottomPadding(context),
              ),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => context.push('/users/${item.authorId}'),
                      borderRadius: BorderRadius.circular(24),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor:
                            isMe ? colorScheme.primaryContainer : null,
                        child: Text(
                          item.authorInitial,
                          style: AppTypography.avatarInitial(large: true),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.authorLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.authorNameDetail(context),
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'You',
                                    style: AppTypography.badge(context),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (item.authorSubtitle != null)
                            Text(
                              item.authorSubtitle!,
                              style: AppTypography.metaMuted(context),
                            ),
                          Text(
                            _formatTimestamp(item.createdAt),
                            style: AppTypography.meta(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => context.push('/goals/${item.goalId}'),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            [
                              item.goalTitle,
                              item.contextLabel,
                              if (item.logDateLabel != null) item.logDateLabel,
                            ].join(' · '),
                            style: AppTypography.meta(context),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.activitySummary(postKind),
                  style: AppTypography.metaMuted(context),
                ),
                if (postKind != FeedPostKind.unknown) ...[
                  const SizedBox(height: 12),
                  FeedPostBody(item: item),
                ],
                const SizedBox(height: 20),
                Text('Reactions', style: AppTypography.sectionTitle(context)),
                const SizedBox(height: 8),
                LogReactionBar(logId: item.logId),
                const SizedBox(height: 20),
                Text('Comments', style: AppTypography.sectionTitle(context)),
                const SizedBox(height: 4),
                CommentSection(
                  logId: item.logId,
                  initialExpanded: true,
                  showExpandToggle: false,
                  onCommentsChanged: () {
                    ref.invalidate(feedPostProvider(logId));
                    ref.invalidate(feedProvider);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 6) {
      return DateFormat.yMMMd().add_jm().format(time);
    }
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
