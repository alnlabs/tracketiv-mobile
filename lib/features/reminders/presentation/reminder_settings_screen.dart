import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/reminder.dart';
import '../../../shared/utils/cadence_utils.dart';
import '../../../shared/widgets/filter_pill.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../../shared/widgets/tracketiv_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../goals/providers/goals_provider.dart';
import '../providers/reminder_provider.dart';
import '../utils/reminder_scheduler.dart';
import 'package:tracketiv/shared/utils/api_error_formatter.dart';

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
  String _cadence = 'daily';
  int? _cadenceIntervalDays;
  DateTime _goalCreatedAt = DateTime.now();

  static const _dayLabels = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};

  void _loadFromReminder(Reminder? reminder) {
    if (_initialized) return;
    if (reminder != null) {
      final parts = reminder.timeOfDay.split(':');
      _time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      _days
        ..clear()
        ..addAll(reminder.daysOfWeek);
      _enabled = reminder.enabled;
    } else {
      _days
        ..clear()
        ..addAll(
          CadenceUtils.defaultReminderDays(
            _cadence,
            goalCreatedAt: _goalCreatedAt,
          ),
        );
      _enabled = true;
    }
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
        goalTitle: goal.title,
        goalCadence: goal.cadence,
        goalCadenceIntervalDays: goal.cadenceIntervalDays,
        goalCreatedAt: goal.createdAt,
      );

      await ref.read(reminderRepositoryProvider).upsertReminder(reminder);
      await ReminderScheduler.apply(reminder);

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
    final goalAsync = ref.watch(goalDetailProvider(widget.goalId));

    return Scaffold(
      appBar: const TracketivAppBar(title: 'Log reminder'),
      body: goalAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toUserMessage())),
        data: (goal) {
          _cadence = goal.cadence;
          _cadenceIntervalDays = goal.cadenceIntervalDays;
          _goalCreatedAt = goal.createdAt;

          return reminderAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(e.toUserMessage())),
            data: (reminder) {
              _loadFromReminder(reminder);

              final scheduleHint = CadenceUtils.reminderScheduleHint(
                _cadence,
                intervalDays: _cadenceIntervalDays,
                goalCreatedAt: _goalCreatedAt,
              );
              final showDayPicker = CadenceUtils.showsDayPicker(_cadence);

              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal.title,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CadenceUtils.label(_cadence, intervalDays: _cadenceIntervalDays),
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              scheduleHint,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable reminder'),
                      subtitle: const Text('Device notification to log this goal'),
                      value: _enabled,
                      onChanged: (v) => setState(() => _enabled = v),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Reminder time'),
                      subtitle: Text(_time.format(context)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final picked = await showTimePicker(context: context, initialTime: _time);
                        if (picked != null) setState(() => _time = picked);
                      },
                    ),
                    if (showDayPicker) ...[
                      const SizedBox(height: 16),
                      Text('Reminder days', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _dayLabels.entries.map((e) {
                          final selected = _days.contains(e.key);
                          return FilterPill(
                            label: e.value,
                            selected: selected,
                            onTap: () {
                              setState(() {
                                if (_cadence == 'weekly') {
                                  _days
                                    ..clear()
                                    ..add(e.key);
                                } else if (selected) {
                                  if (_days.length > 1) _days.remove(e.key);
                                } else {
                                  _days.add(e.key);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
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
          );
        },
      ),
    );
  }
}
