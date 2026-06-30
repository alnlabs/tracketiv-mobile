import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/social_provider.dart';
import 'package:tracketiv/shared/utils/api_error_formatter.dart';

class CommentSection extends ConsumerStatefulWidget {
  const CommentSection({
    super.key,
    required this.logId,
    this.initialExpanded = false,
    this.showExpandToggle = true,
    this.onCommentsChanged,
  });

  final String logId;
  final bool initialExpanded;
  final bool showExpandToggle;
  final VoidCallback? onCommentsChanged;

  @override
  ConsumerState<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends ConsumerState<CommentSection> {
  final _controller = TextEditingController();
  late bool _expanded;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initialExpanded;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _controller.text.trim();
    if (body.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Write a comment before sending.')),
        );
      }
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to comment.')),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(socialRepositoryProvider).addComment(
            logId: widget.logId,
            authorId: user.id,
            body: body,
          );
      _controller.clear();
      ref.invalidate(logCommentsProvider(widget.logId));
      widget.onCommentsChanged?.call();
      if (mounted) setState(() => _expanded = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add comment. ${e.toUserMessage()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildComposer() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: _isSubmitting ? null : (_) => _submit(),
            decoration: const InputDecoration(
              hintText: 'Add a comment...',
              isDense: true,
            ),
          ),
        ),
        IconButton(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(logCommentsProvider(widget.logId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showExpandToggle)
          TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            label: commentsAsync.maybeWhen(
              data: (c) => Text('${c.length} comment${c.length == 1 ? '' : 's'}'),
              orElse: () => const Text('Comments'),
            ),
          ),
        if (_expanded) ...[
          commentsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(e.toUserMessage()),
            ),
            data: (comments) {
              if (comments.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'No comments yet.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }
              return Column(
                children: comments
                    .map(
                      (c) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 14,
                          child: Text(
                            (c.authorName ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        title: Text(
                          c.authorName ?? 'User',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        subtitle: Text(c.body),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          _buildComposer(),
        ],
      ],
    );
  }
}
