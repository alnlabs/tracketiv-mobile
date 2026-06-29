import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/goal_template.dart';
import '../../../shared/models/user_goal.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/goals_provider.dart';

class JoinGoalScreen extends ConsumerStatefulWidget {
  const JoinGoalScreen({super.key, required this.template});

  final GoalTemplate template;

  @override
  ConsumerState<JoinGoalScreen> createState() => _JoinGoalScreenState();
}

class _JoinGoalScreenState extends ConsumerState<JoinGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _targetController = TextEditingController();
  final _startController = TextEditingController();
  final _inviteController = TextEditingController();

  String _mode = 'solo';
  DateTime _targetDate = DateTime.now().add(const Duration(days: 90));
  bool _isLoading = false;
  String? _error;
  final List<Map<String, dynamic>> _invitees = [];

  @override
  void initState() {
    super.initState();
    final defaultTarget = widget.template.defaultTarget['target_value'];
    if (defaultTarget != null) {
      _targetController.text = defaultTarget.toString();
    }
    final months = widget.template.defaultTarget['duration_months'] as int?;
    if (months != null) {
      _targetDate = DateTime.now().add(Duration(days: months * 30));
    }
  }

  @override
  void dispose() {
    _targetController.dispose();
    _startController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _searchInvitee() async {
    final query = _inviteController.text.trim();
    if (query.isEmpty) return;
    final results = await ref.read(goalsRepositoryProvider).searchProfiles(query);
    if (!mounted) return;
    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No users found with that name')),
      );
      return;
    }
    setState(() {
      for (final r in results) {
        if (!_invitees.any((i) => i['id'] == r['id'])) {
          _invitees.add(r);
        }
      }
      _inviteController.clear();
    });
  }

  Future<void> _joinGoal() async {
    if (!_formKey.currentState!.validate()) return;
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
        mode: _mode,
        cadence: widget.template.cadence,
        metricType: widget.template.metricType,
        metricUnit: widget.template.metricUnit,
        targetValue: double.tryParse(_targetController.text),
        startValue: double.tryParse(_startController.text),
        targetDate: _targetDate,
        status: 'active',
        createdAt: DateTime.now(),
      );

      final created = await ref.read(goalsRepositoryProvider).createGoal(goal);

      for (final invitee in _invitees) {
        await ref.read(goalsRepositoryProvider).addMember(
              goalId: created.id,
              userId: invitee['id'] as String,
            );
      }

      ref.invalidate(myGoalsProvider);
      if (!mounted) return;
      context.go('/goals/${created.id}');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Join ${widget.template.title}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.template.description ?? '', style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 24),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'solo', label: Text('Solo'), icon: Icon(Icons.person)),
                  ButtonSegment(value: 'group', label: Text('Group'), icon: Icon(Icons.groups)),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _startController,
                decoration: InputDecoration(
                  labelText: 'Starting ${widget.template.metricUnit ?? 'value'}',
                  hintText: 'e.g. 95 for weight in kg',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetController,
                decoration: InputDecoration(
                  labelText: 'Target ${widget.template.metricUnit ?? 'value'}',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => Validators.numeric(v, field: 'Target'),
              ),
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
              if (_mode == 'group') ...[
                const SizedBox(height: 16),
                const Text('Invite members (search by display name)'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inviteController,
                        decoration: const InputDecoration(hintText: 'Search name'),
                      ),
                    ),
                    IconButton(onPressed: _searchInvitee, icon: const Icon(Icons.person_add)),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: _invitees.map((i) {
                    return Chip(
                      label: Text(i['display_name'] as String? ?? 'User'),
                      onDeleted: () => setState(() => _invitees.remove(i)),
                    );
                  }).toList(),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              LoadingButton(
                onPressed: _joinGoal,
                label: 'Start tracking',
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
