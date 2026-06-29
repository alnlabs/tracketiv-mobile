import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/social_provider.dart';

class CommentSection extends ConsumerStatefulWidget {
  const CommentSection({super.key, required this.logId});

  final String logId;

  @override
  ConsumerState<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends ConsumerState<CommentSection> {
  final _controller = TextEditingController();
  bool _expanded = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(socialRepositoryProvider).addComment(
            logId: widget.logId,
            authorId: user.id,
            body: body,
          );
      _controller.clear();
      ref.invalidate(logCommentsProvider(widget.logId));
      setState(() => _expanded = true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(logCommentsProvider(widget.logId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _expanded = !_expanded),
          icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
          label: commentsAsync.maybeWhen(
            data: (c) => Text('${c.length} comment${c.length == 1 ? '' : 's'}'),
            orElse: () => const Text('Comments'),
          ),
        ),
        if (_expanded)
          commentsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),
            error: (e, _) => Text(e.toString()),
            data: (comments) => Column(
              children: [
                ...comments.map((c) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 14,
                        child: Text((c.authorName ?? 'U')[0].toUpperCase(), style: const TextStyle(fontSize: 12)),
                      ),
                      title: Text(c.authorName ?? 'User', style: Theme.of(context).textTheme.labelMedium),
                      subtitle: Text(c.body),
                    )),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Add a comment...',
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
