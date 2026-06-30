import 'package:flutter/material.dart';

import '../models/invitable_user.dart';
import '../theme/app_typography.dart';

/// Search result row for invitable users — avoids ListTile trailing squeeze.
class InvitableUserRow extends StatelessWidget {
  const InvitableUserRow({
    super.key,
    required this.user,
    required this.actionLabel,
    required this.onAction,
    this.onTap,
    this.isActionEnabled = true,
    this.actionIcon = Icons.person_add_outlined,
  });

  final InvitableUser user;
  final String actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onTap;
  final bool isActionEnabled;
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage:
                    user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                child: user.avatarUrl == null
                    ? Text(user.initials, style: AppTypography.avatarInitial())
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cardTitle(context, weight: FontWeight.w600),
                    ),
                    if (user.subtitle != null)
                      Text(
                        user.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: isActionEnabled ? onAction : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(actionIcon, size: 18),
                    const SizedBox(width: 4),
                    Text(actionLabel),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
