import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/goal_template.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/models/user_goal.dart';
import '../../../shared/utils/cadence_utils.dart';
import '../../../shared/utils/metric_utils.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/utils/weight_utils.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../../shared/widgets/tracketiv_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/goals_provider.dart';
import 'package:tracketiv/shared/utils/api_error_formatter.dart';

class JoinGoalScreen extends ConsumerStatefulWidget {
  const JoinGoalScreen({
    super.key,
    required this.template,
    this.groupId,
  });

  final GoalTemplate template;
  final String? groupId;

  @override
  ConsumerState<JoinGoalScreen> createState() => _JoinGoalScreenState();
}

class _JoinGoalScreenState extends ConsumerState<JoinGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _targetController = TextEditingController();
  final _startController = TextEditingController();
  final _customIntervalController = TextEditingController();

  late String _cadence;
  DateTime _targetDate = DateTime.now().add(const Duration(days: 90));
  bool _isLoading = false;
  bool _prefilledStart = false;
  String? _error;

  bool get _isGroupGoal => widget.groupId != null;

  @override
  void initState() {
    super.initState();
    _cadence = widget.template.cadence;
    final defaultTarget = widget.template.defaultTarget['target_value'];
    if (defaultTarget != null) {
      _targetController.text = defaultTarget.toString();
    }
    final months = widget.template.defaultTarget['duration_months'] as int?;
    if (months != null) {
      _targetDate = DateTime.now().add(Duration(days: months * 30));
    }
  }

  void _prefillFromProfile(Profile? profile) {
    if (_prefilledStart || profile == null || widget.template.metricType != 'weight') return;
    if (profile.weightKg != null) {
      final display = WeightUtils.kgToDisplay(profile.weightKg!, profile.weightUnit);
      _startController.text = display.toStringAsFixed(1);
      _prefilledStart = true;
    }
  }

  @override
  void dispose() {
    _targetController.dispose();
    _startController.dispose();
    _customIntervalController.dispose();
    super.dispose();
  }

  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) return;

    final metricConfig = MetricUtils.config(
      widget.template.metricType,
      widget.template.metricUnit,
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

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final goal = UserGoal(
        id: '',
        templateId: widget.template.id,
        ownerId: user.id,
        title: widget.template.title,
        description: widget.template.description,
        mode: _isGroupGoal ? 'group' : 'solo',
        cadence: _cadence,
        cadenceIntervalDays: intervalDays,
        metricType: widget.template.metricType,
        metricUnit: widget.template.metricUnit,
        targetValue: metricConfig.showTargetValue
            ? double.tryParse(_targetController.text)
            : (widget.template.defaultTarget['target_value'] as num?)?.toDouble(),
        startValue: metricConfig.showStartValue
            ? double.tryParse(_startController.text)
            : null,
        targetDate: metricConfig.showTargetDate ? _targetDate : null,
        status: 'active',
        createdAt: DateTime.now(),
        groupId: widget.groupId,
      );

      final created = await ref.read(goalsRepositoryProvider).createGoal(goal);

      ref.invalidate(myGoalsProvider);
      ref.invalidate(myGroupsProvider);
      if (widget.groupId != null) {
        ref.invalidate(groupGoalsProvider(widget.groupId!));
      }

      if (!mounted) return;
      if (widget.groupId != null) {
        context.go('/groups/${widget.groupId}');
      } else {
        context.go('/goals/${created.id}');
      }
    } catch (e) {
      setState(() => _error = e.toUserMessage());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    _prefillFromProfile(profile);

    final groupAsync = widget.groupId != null
        ? ref.watch(groupDetailProvider(widget.groupId!))
        : null;

    final metricConfig = MetricUtils.config(
      widget.template.metricType,
      widget.template.metricUnit,
      cadence: _cadence,
    );

    return Scaffold(
      appBar: TracketivAppBar(
        title: widget.template.title,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isGroupGoal)
                groupAsync?.when(
                  data: (group) => Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.groups),
                      title: Text(group.name),
                      subtitle: const Text('This goal will be shared with the whole group'),
                    ),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                ) ??
                    const SizedBox.shrink(),
              Text(
                widget.template.description ?? '',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Text('Tracking interval', style: AppTypography.sectionTitle(context)),
              const SizedBox(height: 4),
              Text(
                CadenceUtils.hint(_cadence, intervalDays: int.tryParse(_customIntervalController.text)),
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
                  subtitle: Text('${_targetDate.day}/${_targetDate.month}/${_targetDate.year}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _targetDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                    );
                    if (picked != null) setState(() => _targetDate = picked);
                  },
                ),
              ],
              if (!metricConfig.showStartValue &&
                  !metricConfig.showTargetValue &&
                  !metricConfig.showTargetDate) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Just pick your tracking interval and start logging. '
                      'No numeric target needed for this habit.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              LoadingButton(
                onPressed: _saveGoal,
                label: _isGroupGoal ? 'Add to group' : 'Start tracking',
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
