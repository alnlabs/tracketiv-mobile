import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/log.dart';
import '../../../shared/models/post_type.dart';
import '../../../shared/models/reminder.dart';
import '../../../shared/utils/metric_utils.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../../shared/widgets/tracketiv_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../feed/providers/feed_provider.dart';
import '../../goals/providers/goals_provider.dart';
import '../../reminders/providers/reminder_provider.dart';
import '../../reminders/utils/reminder_scheduler.dart';
import '../providers/logs_provider.dart';
import 'package:tracketiv/shared/utils/api_error_formatter.dart';

class AddLogScreen extends ConsumerStatefulWidget {
  const AddLogScreen({
    super.key,
    required this.goalId,
    this.postType = PostType.metric,
  });

  final String goalId;
  final PostType postType;

  @override
  ConsumerState<AddLogScreen> createState() => _AddLogScreenState();
}

class _AddLogScreenState extends ConsumerState<AddLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _updatingToday = false;

  bool get _isNoteOnly => widget.postType == PostType.note;
  bool get _isCheckIn => widget.postType == PostType.checkIn;

  @override
  void initState() {
    super.initState();
    if (_isCheckIn) {
      _noteController.text = 'Checked in today';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkTodayLog());
  }

  Future<void> _checkTodayLog() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final hasToday = await ref.read(logsRepositoryProvider).hasTodayLog(widget.goalId, user.id);
    if (!mounted || !hasToday) return;
    setState(() => _updatingToday = true);
  }

  @override
  void dispose() {
    _valueController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<bool> _confirmUpdateToday() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Already logged today'),
        content: const Text(
          'You already added a log for today. Do you want to update it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final existingToday =
        await ref.read(logsRepositoryProvider).hasTodayLog(widget.goalId, user.id);
    if (existingToday) {
      if (!mounted) return;
      final confirmed = await _confirmUpdateToday();
      if (!confirmed) return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final noteText = _noteController.text.trim();
      final log = LogEntry(
        id: '',
        userGoalId: widget.goalId,
        authorId: user.id,
        logDate: DateTime.now(),
        value: _isNoteOnly || _isCheckIn
            ? null
            : double.tryParse(_valueController.text),
        note: noteText.isEmpty ? null : noteText,
        createdAt: DateTime.now(),
      );

      await ref.read(logsRepositoryProvider).createLog(log);
      ref.invalidate(goalLogsProvider(widget.goalId));
      ref.invalidate(myGoalLogsProvider(widget.goalId));
      ref.invalidate(everyoneLoggedTodayProvider(widget.goalId));
      ref.invalidate(feedProvider);

      if (!mounted) return;
      context.pop();

      // Reschedule reminders after save — must not block or undo a successful log.
      try {
        final existingReminder =
            await ref.read(reminderRepositoryProvider).getReminder(widget.goalId, user.id);
        if (existingReminder?.enabled == true) {
          final goal = await ref.read(goalsRepositoryProvider).getGoal(widget.goalId);
          await ReminderScheduler.apply(
            Reminder(
              id: existingReminder!.id,
              userGoalId: widget.goalId,
              userId: user.id,
              timeOfDay: existingReminder.timeOfDay,
              daysOfWeek: existingReminder.daysOfWeek,
              enabled: true,
              goalTitle: goal.title,
              goalCadence: goal.cadence,
              goalCadenceIntervalDays: goal.cadenceIntervalDays,
              goalCreatedAt: goal.createdAt,
            ),
          );
        }
      } catch (e) {
        debugPrint('Reminder reschedule after log save failed: $e');
      }
    } catch (e) {
      setState(() => _error = e.toUserMessage());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _titleForType() {
    switch (widget.postType) {
      case PostType.metric:
        return 'Log progress';
      case PostType.note:
        return 'Share update';
      case PostType.checkIn:
        return 'Quick check-in';
    }
  }

  @override
  Widget build(BuildContext context) {
    final goalAsync = ref.watch(goalDetailProvider(widget.goalId));

    return Scaffold(
      appBar: TracketivAppBar(title: _titleForType()),
      body: goalAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toUserMessage())),
        data: (goal) {
          final metricConfig = MetricUtils.config(
            goal.metricType,
            goal.metricUnit,
            cadence: goal.cadence,
          );

          return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: ListTile(
                    leading: Icon(widget.postType.icon),
                    title: Text(goal.title),
                    subtitle: Text(
                      _updatingToday
                          ? 'Updates your log for today'
                          : _isNoteOnly
                              ? 'This update will appear on your feed'
                              : _isCheckIn
                                  ? 'Mark your progress for today'
                                  : 'Log your ${goal.cadenceLabel.toLowerCase()} progress',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (!_isNoteOnly && !_isCheckIn)
                  TextFormField(
                    controller: _valueController,
                    decoration: InputDecoration(
                      labelText: metricConfig.logValueLabel,
                      hintText: metricConfig.logValueHint,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => Validators.numeric(v, field: metricConfig.logValueLabel),
                  ),
                if (_isNoteOnly || _isCheckIn) ...[
                  TextFormField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      labelText: _isCheckIn ? 'Note (optional)' : 'Your update',
                      hintText: _isNoteOnly
                          ? 'How did it go today? Share with your group...'
                          : 'Optional note for your check-in',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 5,
                    validator: _isNoteOnly
                        ? (v) => (v == null || v.trim().isEmpty) ? 'Write something to post' : null
                        : null,
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      hintText: 'e.g. Had a cheat meal today, or controlled myself at the party',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                LoadingButton(
                  onPressed: _submit,
                  label: _updatingToday
                      ? 'Update today\'s log'
                      : _isNoteOnly
                          ? 'Post update'
                          : _isCheckIn
                              ? 'Check in'
                              : 'Save log',
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        );
        },
      ),
    );
  }
}
