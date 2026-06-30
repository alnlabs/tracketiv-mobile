import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/log_reaction.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/social_provider.dart';
import 'reaction_chip.dart';
import 'reaction_picker_sheet.dart';

/// Single reaction UI used across feed, goal detail, and anywhere else.
class LogReactionBar extends ConsumerWidget {
  const LogReactionBar({
    super.key,
    required this.logId,
    this.trailing,
    this.compact = false,
  });

  final String logId;
  final Widget? trailing;
  /// Hides placeholder text when there are no reactions (feed cards).
  final bool compact;

  Future<void> _toggle(WidgetRef ref, String userId, String emojiType) async {
    await ref.read(socialRepositoryProvider).toggleReaction(
          logId: logId,
          userId: userId,
          emojiType: emojiType,
        );
    ref.invalidate(logReactionsProvider(logId));
  }

  Future<void> _pickReaction(BuildContext context, WidgetRef ref, String userId) async {
    final type = await showReactionPickerSheet(context);
    if (type == null) return;
    await _toggle(ref, userId, type);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reactionsAsync = ref.watch(logReactionsProvider(logId));
    final user = ref.watch(currentUserProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final summaries = reactionsAsync.maybeWhen(
      data: (value) => value,
      orElse: () => const <ReactionSummary>[],
    );

    final active = summaries.where((s) => s.count > 0).toList();

    Widget? addButton;
    if (user != null) {
      addButton = Material(
        color: colorScheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _pickReaction(context, ref, user.id),
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: compact ? 36 : 40,
            height: compact ? 36 : 40,
            child: Icon(
              Icons.add_reaction_outlined,
              size: compact ? 20 : 22,
            ),
          ),
        ),
      );
    }

    Widget reactionsContent;
    if (reactionsAsync.isLoading) {
      reactionsContent = const SizedBox(
        height: 36,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (active.isEmpty) {
      reactionsContent = compact
          ? const SizedBox.shrink()
          : Text(
              'Be the first to react',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            );
    } else {
      reactionsContent = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < active.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              ReactionChip(
                emojiType: active[i].emojiType,
                count: active[i].count,
                reactedByMe: active[i].reactedByMe,
                onTap: user == null
                    ? null
                    : () => _toggle(
                          ref,
                          user.id,
                          active[i].emojiType,
                        ),
              ),
            ],
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (addButton != null) addButton,
        if (addButton != null &&
            (active.isNotEmpty || reactionsAsync.isLoading || !compact))
          const SizedBox(width: 8),
        Expanded(child: reactionsContent),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}
