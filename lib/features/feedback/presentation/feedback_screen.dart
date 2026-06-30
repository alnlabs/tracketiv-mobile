import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/utils/scaffold_layout.dart';
import '../../../shared/utils/api_error_formatter.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../../shared/widgets/tracketiv_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/feedback_provider.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _emailController = TextEditingController();

  String _type = 'suggestion';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider);
      if (user?.email != null && _emailController.text.isEmpty) {
        _emailController.text = user!.email!;
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final profile = ref.read(currentProfileProvider).valueOrNull;
      await ref.read(feedbackRepositoryProvider).submitFeedback(
            type: _type,
            message: _messageController.text.trim(),
            contactEmail: _emailController.text.trim(),
            displayName: profile?.publicName,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks! Your feedback was sent.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send feedback. ${e.toUserMessage()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TracketivAppBar(title: 'Send feedback'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          listScrollBottomPadding(context, base: 24),
        ),
        children: [
          Text(
            'Share a suggestion, improvement idea, or report an issue. '
            'We read every message sent to ${AppConstants.feedbackEmail}.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Type', style: AppTypography.sectionTitle(context)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: AppConstants.feedbackTypes
                      .map(
                        (type) => ButtonSegment<String>(
                          value: type,
                          label: Text(AppConstants.feedbackTypeLabels[type]!),
                        ),
                      )
                      .toList(),
                  selected: {_type},
                  onSelectionChanged: (value) => setState(() => _type = value.first),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Your email (optional)',
                    hintText: 'So we can reply if needed',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    labelText: _messageLabel,
                    hintText: _messageHint,
                    alignLabelWithHint: true,
                  ),
                  maxLines: 6,
                  maxLength: 2000,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.length < 10) {
                      return 'Please enter at least 10 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                LoadingButton(
                  onPressed: _submit,
                  label: 'Send feedback',
                  isLoading: _isSubmitting,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _messageLabel {
    switch (_type) {
      case 'improvement':
        return 'What should we improve?';
      case 'issue':
        return 'Describe the issue';
      default:
        return 'Your suggestion';
    }
  }

  String get _messageHint {
    switch (_type) {
      case 'improvement':
        return 'Tell us what could work better...';
      case 'issue':
        return 'What happened? Steps to reproduce help...';
      default:
        return 'Share your idea...';
    }
  }
}
