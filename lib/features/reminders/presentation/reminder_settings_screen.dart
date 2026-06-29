import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/reminder.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../goals/providers/goals_provider.dart';
import '../providers/reminder_provider.dart';
import '../services/notification_service.dart';

class ReminderSettingsScreen extends ConsumerStatefulWidget {
  const ReminderSettingsScreen({super.key, required this.goalId});

  final String goalId;

  @override
  ConsumerState<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends ConsumerState<ReminderSettingsScreen> {
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  final Set<int> _days = {1, 2, 3, 4, 5, 6, 7};
  bool _enabled = true;
  bool _isLoading = false;
  bool _initialized = false;

  static const _dayLabels = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};

  void _loadFromReminder(Reminder? reminder) {
    if (_initialized || reminder == null) return;
    final parts = reminder.timeOfDay.split(':');
    _time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    _days
      ..clear()
      ..addAll(reminder.daysOfWeek);
    _enabled = reminder.enabled;
    _initialized = true;
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final goal = await ref.read(goalsRepositoryProvider).getGoal(widget.goalId);
      final timeStr =
          '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}:00';

      final reminder = Reminder(
        id: '',
        userGoalId: widget.goalId,
        userId: user.id,
        timeOfDay: timeStr,
        daysOfWeek: _days.toList()..sort(),
        enabled: _enabled,
      );

      await ref.read(reminderRepositoryProvider).upsertReminder(reminder);

      if (_enabled) {
        await NotificationService.instance.scheduleDailyReminder(
          id: widget.goalId.hashCode,
          title: 'Time to log!',
          body: 'Don\'t forget to log your progress for ${goal.title}',
          hour: _time.hour,
          minute: _time.minute,
          daysOfWeek: _days.toList(),
        );
      } else {
        await NotificationService.instance.cancel(widget.goalId.hashCode);
      }

      ref.invalidate(goalReminderProvider(widget.goalId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder saved')),
        );
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reminderAsync = ref.watch(goalReminderProvider(widget.goalId));

    return Scaffold(
      appBar: AppBar(title: const Text('Reminder')),
      body: reminderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (reminder) {
          _loadFromReminder(reminder);

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  title: const Text('Enable reminder'),
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
                ListTile(
                  title: const Text('Time'),
                  subtitle: Text(_time.format(context)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: _time);
                    if (picked != null) setState(() => _time = picked);
                  },
                ),
                const SizedBox(height: 16),
                Text('Days', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _dayLabels.entries.map((e) {
                    final selected = _days.contains(e.key);
                    return FilterChip(
                      label: Text(e.value),
                      selected: selected,
                      onSelected: (s) {
                        setState(() {
                          if (s) {
                            _days.add(e.key);
                          } else {
                            _days.remove(e.key);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const Spacer(),
                LoadingButton(
                  onPressed: _save,
                  label: 'Save reminder',
                  isLoading: _isLoading,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
