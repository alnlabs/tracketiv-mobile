import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/social_provider.dart';

class ReactionBar extends ConsumerWidget {
  const ReactionBar({super.key, required this.logId});

  final String logId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reactionsAsync = ref.watch(logReactionsProvider(logId));
    final user = ref.watch(currentUserProvider);

    return reactionsAsync.when(
      loading: () => const SizedBox(height: 36),
      error: (_, __) => const SizedBox.shrink(),
      data: (summaries) {
        return Wrap(
          spacing: 4,
          children: summaries.map((summary) {
            final emoji = AppConstants.reactionEmojis[summary.emojiType] ?? '👍';
            return InkWell(
              onTap: user == null
                  ? null
                  : () async {
                      await ref.read(socialRepositoryProvider).toggleReaction(
                            logId: logId,
                            userId: user.id,
                            emojiType: summary.emojiType,
                          );
                      ref.invalidate(logReactionsProvider(logId));
                    },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: summary.reactedByMe
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$emoji ${summary.count > 0 ? summary.count : ''}'.trim(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
