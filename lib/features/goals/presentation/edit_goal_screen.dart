import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/user_goal.dart';
import '../../../shared/utils/cadence_utils.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/utils/metric_utils.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../../shared/widgets/tracketiv_app_bar.dart';
import '../../feed/providers/feed_provider.dart';
import '../providers/goals_provider.dart';
import 'package:tracketiv/shared/utils/api_error_formatter.dart';

class EditGoalScreen extends ConsumerStatefulWidget {
  const EditGoalScreen({super.key, required this.goalId});

  final String goalId;

  @override
  ConsumerState<EditGoalScreen> createState() => _EditGoalScreenState();
}

class _EditGoalScreenState extends ConsumerState<EditGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetController = TextEditingController();
  final _startController = TextEditingController();
  final _customIntervalController = TextEditingController();

  UserGoal? _goal;
  late String _cadence;
  late String _status;
  DateTime? _targetDate;
  bool _isLoading = false;
  bool _initialized = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    _startController.dispose();
    _customIntervalController.dispose();
    super.dispose();
  }

  void _loadGoal(UserGoal goal) {
    if (_initialized) return;
    _goal = goal;
    _cadence = goal.cadence;
    _status = goal.status;
    _targetDate = goal.targetDate;
    _titleController.text = goal.title;
    _descriptionController.text = goal.description ?? '';
    if (goal.targetValue != null) {
      _targetController.text = goal.targetValue.toString();
    }
    if (goal.startValue != null) {
      _startController.text = goal.startValue.toString();
    }
    if (goal.cadenceIntervalDays != null) {
      _customIntervalController.text = goal.cadenceIntervalDays.toString();
    }
    _initialized = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _goal == null) return;

    final metricConfig = MetricUtils.config(
      _goal!.metricType,
      _goal!.metricUnit,
      cadence: _cadence,
    );

    int? intervalDays;
    if (_cadence == 'custom') {
      intervalDays = int.tryParse(_customIntervalController.text.trim());
      if (intervalDays == null || intervalDays < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter how many days between check-ins')),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final updated = UserGoal(
        id: _goal!.id,
        templateId: _goal!.templateId,
        ownerId: _goal!.ownerId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        mode: _goal!.mode,
        cadence: _cadence,
        cadenceIntervalDays: intervalDays,
        metricType: _goal!.metricType,
        metricUnit: _goal!.metricUnit,
        targetValue: metricConfig.showTargetValue
            ? double.tryParse(_targetController.text)
            : _goal!.targetValue,
        startValue: metricConfig.showStartValue
            ? double.tryParse(_startController.text)
            : _goal!.startValue,
        targetDate: metricConfig.showTargetDate ? _targetDate : null,
        status: _status,
        createdAt: _goal!.createdAt,
        groupId: _goal!.groupId,
        groupName: _goal!.groupName,
      );

      await ref.read(goalsRepositoryProvider).updateGoal(updated);

      ref.invalidate(goalDetailProvider(widget.goalId));
      ref.invalidate(myGoalsProvider);
      ref.invalidate(feedProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal updated')),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _error = e.toUserMessage());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goalAsync = ref.watch(goalDetailProvider(widget.goalId));
    final isOwnerAsync = ref.watch(isGoalOwnerProvider(widget.goalId));

    return Scaffold(
      appBar: const TracketivAppBar(title: 'Edit goal'),
      body: goalAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e,
          onRetry: () => ref.invalidate(goalDetailProvider(widget.goalId)),
        ),
        data: (goal) {
          if (goal.isGroup) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Group goals are managed at the group level.'),
              ),
            );
          }

          return isOwnerAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(error: e),
            data: (isOwner) {
              if (!isOwner) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Only the goal owner can edit this goal.'),
                  ),
                );
              }

              _loadGoal(goal);
              final metricConfig = MetricUtils.config(
                goal.metricType,
                goal.metricUnit,
                cadence: _cadence,
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(labelText: 'Goal name'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                          alignLabelWithHint: true,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),
                      Text('Status', style: AppTypography.sectionTitle(context)),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'active', label: Text('Active')),
                          ButtonSegment(value: 'completed', label: Text('Done')),
                          ButtonSegment(value: 'archived', label: Text('Paused')),
                        ],
                        selected: {_status},
                        onSelectionChanged: (s) => setState(() => _status = s.first),
                      ),
                      const SizedBox(height: 24),
                      Text('Tracking interval', style: AppTypography.sectionTitle(context)),
                      const SizedBox(height: 4),
                      Text(
                        CadenceUtils.hint(
                          _cadence,
                          intervalDays: int.tryParse(_customIntervalController.text),
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'daily', label: Text('Daily')),
                          ButtonSegment(value: 'weekly', label: Text('Weekly')),
                          ButtonSegment(value: 'monthly', label: Text('Monthly')),
                          ButtonSegment(value: 'custom', label: Text('Custom')),
                        ],
                        selected: {_cadence},
                        onSelectionChanged: (s) => setState(() => _cadence = s.first),
                      ),
                      if (_cadence == 'custom') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _customIntervalController,
                          decoration: const InputDecoration(
                            labelText: 'Days between check-ins',
                            hintText: 'e.g. 3 for every 3 days',
                            prefixIcon: Icon(Icons.repeat),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            if (_cadence != 'custom') return null;
                            final days = int.tryParse(v?.trim() ?? '');
                            if (days == null || days < 1) return 'Enter at least 1 day';
                            return null;
                          },
                        ),
                      ],
                      if (metricConfig.showStartValue) ...[
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _startController,
                          decoration: InputDecoration(
                            labelText: metricConfig.startLabel,
                            hintText: metricConfig.startHint,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ],
                      if (metricConfig.showTargetValue) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _targetController,
                          decoration: InputDecoration(
                            labelText: metricConfig.targetLabel,
                            hintText: metricConfig.targetHint,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: metricConfig.targetRequired
                              ? (v) => Validators.numeric(v, field: 'Target')
                              : (v) {
                                  if (v == null || v.trim().isEmpty) return null;
                                  return Validators.numeric(v, field: 'Target');
                                },
                        ),
                      ],
                      if (metricConfig.showTargetDate) ...[
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Target date'),
                          subtitle: Text(
                            _targetDate != null
                                ? '${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}'
                                : 'Not set',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 90)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                            );
                            if (picked != null) setState(() => _targetDate = picked);
                          },
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ],
                      const SizedBox(height: 24),
                      LoadingButton(
                        onPressed: _save,
                        label: 'Save changes',
                        isLoading: _isLoading,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
