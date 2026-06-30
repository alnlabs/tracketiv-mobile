import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/goal_template.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../goals/providers/goals_provider.dart';
import '../providers/admin_provider.dart';
import 'package:tracketiv/shared/utils/api_error_formatter.dart';

class AdminTemplateFormScreen extends ConsumerStatefulWidget {
  const AdminTemplateFormScreen({super.key, this.template});

  final GoalTemplate? template;

  @override
  ConsumerState<AdminTemplateFormScreen> createState() => _AdminTemplateFormScreenState();
}

class _AdminTemplateFormScreenState extends ConsumerState<AdminTemplateFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _metricUnitController = TextEditingController();
  final _iconController = TextEditingController();
  final _targetValueController = TextEditingController();

  static const _categories = [
    'fitness',
    'health',
    'nutrition',
    'mindfulness',
    'learning',
    'finance',
    'productivity',
  ];

  static const _metricTypes = [
    'weight',
    'steps',
    'distance',
    'volume',
    'duration',
    'count',
    'currency',
  ];

  static const _cadences = ['daily', 'weekly', 'monthly', 'custom'];

  late String _category;
  late String _metricType;
  late String _cadence;
  bool _isLoading = false;

  bool get _isEditing => widget.template != null;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _titleController.text = t?.title ?? '';
    _descriptionController.text = t?.description ?? '';
    _metricUnitController.text = t?.metricUnit ?? '';
    _iconController.text = t?.icon ?? '';
    final target = t?.defaultTarget['target_value'];
    if (target != null) _targetValueController.text = target.toString();
    _category = t?.category ?? 'fitness';
    _metricType = t?.metricType ?? 'count';
    _cadence = t?.cadence ?? 'daily';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _metricUnitController.dispose();
    _iconController.dispose();
    _targetValueController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final targetText = _targetValueController.text.trim();
      final template = GoalTemplate(
        id: widget.template?.id ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        category: _category,
        metricType: _metricType,
        metricUnit: _metricUnitController.text.trim().isEmpty
            ? null
            : _metricUnitController.text.trim(),
        cadence: _cadence,
        defaultTarget: targetText.isEmpty
            ? {}
            : {'target_value': num.tryParse(targetText)},
        icon: _iconController.text.trim().isEmpty ? null : _iconController.text.trim(),
      );

      await ref.read(adminRepositoryProvider).upsertTemplate(template);
      ref.invalidate(adminTemplatesProvider);
      ref.invalidate(goalTemplatesProvider(null));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toUserMessage())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit template' : 'New template')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _metricType,
                decoration: const InputDecoration(labelText: 'Metric type'),
                items: _metricTypes
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _metricType = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _metricUnitController,
                decoration: const InputDecoration(
                  labelText: 'Metric unit',
                  hintText: 'e.g. kg, minutes, reps',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _cadence,
                decoration: const InputDecoration(labelText: 'Default cadence'),
                items: _cadences
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _cadence = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetValueController,
                decoration: const InputDecoration(
                  labelText: 'Default target value (optional)',
                  hintText: 'e.g. 10000 for steps',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _iconController,
                decoration: const InputDecoration(
                  labelText: 'Icon key (optional)',
                  hintText: 'e.g. directions_walk, fitness_center',
                ),
              ),
              const SizedBox(height: 24),
              LoadingButton(
                onPressed: _save,
                label: _isEditing ? 'Save changes' : 'Create template',
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
