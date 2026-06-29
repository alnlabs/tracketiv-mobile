import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/log.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../goals/providers/goals_provider.dart';
import '../providers/logs_provider.dart';

class AddLogScreen extends ConsumerStatefulWidget {
  const AddLogScreen({super.key, required this.goalId});

  final String goalId;

  @override
  ConsumerState<AddLogScreen> createState() => _AddLogScreenState();
}

class _AddLogScreenState extends ConsumerState<AddLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _valueController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final log = LogEntry(
        id: '',
        userGoalId: widget.goalId,
        authorId: user.id,
        logDate: DateTime.now(),
        value: double.tryParse(_valueController.text),
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        createdAt: DateTime.now(),
      );

      await ref.read(logsRepositoryProvider).createLog(log);
      ref.invalidate(goalLogsProvider(widget.goalId));
      ref.invalidate(myGoalLogsProvider(widget.goalId));
      ref.invalidate(everyoneLoggedTodayProvider(widget.goalId));

      if (!mounted) return;
      context.pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goalAsync = ref.watch(goalDetailProvider(widget.goalId));

    return Scaffold(
      appBar: AppBar(title: const Text('Add log')),
      body: goalAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (goal) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Log your ${goal.cadence} progress for ${goal.title}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _valueController,
                  decoration: InputDecoration(
                    labelText: '${goal.metricType} (${goal.metricUnit ?? ''})',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => Validators.numeric(v, field: 'Value'),
                ),
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
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                LoadingButton(
                  onPressed: _submit,
                  label: 'Save log',
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
