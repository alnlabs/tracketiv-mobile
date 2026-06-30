import 'package:flutter/material.dart';

import '../../../shared/utils/reactions.dart';

class ReactionChip extends StatelessWidget {
  const ReactionChip({
    super.key,
    required this.emojiType,
    required this.count,
    required this.reactedByMe,
    required this.onTap,
  });

  final String emojiType;
  final int count;
  final bool reactedByMe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final emoji = Reactions.emoji(emojiType);
    const emojiSize = 20.0;

    return Material(
      color: reactedByMe
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      shape: StadiumBorder(
        side: BorderSide(
          color: reactedByMe
              ? colorScheme.primary.withValues(alpha: 0.45)
              : colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: TextStyle(fontSize: emojiSize, height: 1)),
              if (count > 0) ...[
                const SizedBox(width: 5),
                Text(
                  '$count',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1,
                        color: reactedByMe
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurface,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
