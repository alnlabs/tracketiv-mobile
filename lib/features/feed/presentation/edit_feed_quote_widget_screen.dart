import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:tracketiv/shared/utils/api_error_formatter.dart';

import '../../../shared/models/feed_widget.dart';
import '../../../shared/utils/feed_widget_time.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../../shared/widgets/tracketiv_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../goals/providers/goals_provider.dart';
import '../providers/feed_provider.dart';
import '../providers/feed_widget_provider.dart';

class EditFeedQuoteWidgetScreen extends ConsumerStatefulWidget {
  const EditFeedQuoteWidgetScreen({
    super.key,
    this.groupId,
  });

  final String? groupId;

  bool get isGroup => groupId != null;

  @override
  ConsumerState<EditFeedQuoteWidgetScreen> createState() =>
      _EditFeedQuoteWidgetScreenState();
}

class _EditFeedQuoteWidgetScreenState extends ConsumerState<EditFeedQuoteWidgetScreen> {
  TimeOfDay _time = const TimeOfDay(hour: 6, minute: 0);
  bool _enabled = true;
  bool _isLoading = false;
  bool _initialized = false;
  bool _isOwnQuote = false;
  bool _mixAllTopics = true;
  Set<FeedQuoteCategory> _selectedTopics = {};
  final _textController = TextEditingController();
  final _authorController = TextEditingController();
  String? _widgetId;
  String _timezone = 'UTC';

  @override
  void dispose() {
    _textController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  void _loadFromWidget(FeedWidget? existing) {
    if (_initialized) return;
    if (existing != null) {
      _widgetId = existing.id;
      _time = feedWidgetTimeFromStorage(existing.showTime);
      _enabled = existing.enabled;
      _isOwnQuote = existing.config.isOwnQuote;
      _mixAllTopics = existing.config.mixAllTopics;
      _selectedTopics = Set<FeedQuoteCategory>.from(existing.config.categories);
      _textController.text = existing.config.text ?? '';
      _authorController.text = existing.config.author ?? '';
      _timezone = existing.timezone;
    } else {
      _timezone = _resolveDeviceTimezone();
    }
    _initialized = true;
  }

  String _resolveDeviceTimezone() {
    try {
      return tz.local.name;
    } catch (_) {
      return 'UTC';
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    if (_isOwnQuote && _textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type the quote you want to show every day')),
      );
      return;
    }

    if (!_isOwnQuote && !_mixAllTopics && _selectedTopics.isEmpty) {
      setState(() => _mixAllTopics = true);
    }

    setState(() => _isLoading = true);
    try {
      final config = FeedWidgetQuoteConfig(
        source: _isOwnQuote ? FeedWidgetQuoteSource.custom : FeedWidgetQuoteSource.pool,
        text: _isOwnQuote ? _textController.text : null,
        author: _isOwnQuote ? _authorController.text : null,
        mixAllTopics: !_isOwnQuote && _mixAllTopics,
        categories: !_isOwnQuote && !_mixAllTopics ? _selectedTopics : const {},
      );

      await ref.read(feedWidgetRepositoryProvider).upsertFeedWidget(
            widgetId: _widgetId,
            userId: widget.isGroup ? null : user.id,
            groupId: widget.groupId,
            widgetType: FeedWidgetType.quote,
            enabled: _enabled,
            showTime: feedWidgetTimeToStorage(_time),
            timezone: _timezone,
            config: config,
          );

      ref.invalidate(myFeedWidgetsProvider);
      ref.invalidate(feedProvider);
      if (widget.isGroup && widget.groupId != null) {
        ref.invalidate(groupQuoteWidgetProvider(widget.groupId!));
      } else {
        ref.invalidate(personalQuoteWidgetProvider);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _widgetId == null ? 'Daily quote installed' : 'Settings saved',
            ),
          ),
        );
        context.pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toUserMessage())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _scopeLabel(String? groupName) {
    if (widget.isGroup) return groupName ?? 'this group';
    return 'your Feed';
  }

  @override
  Widget build(BuildContext context) {
    final widgetAsync = widget.isGroup
        ? ref.watch(groupQuoteWidgetProvider(widget.groupId!))
        : ref.watch(personalQuoteWidgetProvider);

    final groupAsync = widget.isGroup
        ? ref.watch(groupDetailProvider(widget.groupId!))
        : null;

    final groupName = groupAsync?.maybeWhen(
      data: (g) => g.name,
      orElse: () => null,
    );

    final scope = _scopeLabel(groupName);
    final isInstalling = widgetAsync.maybeWhen(
      data: (w) => w == null,
      orElse: () => true,
    );

    return Scaffold(
      appBar: TracketivAppBar(
        title: 'Daily quote',
        subtitle: widget.isGroup ? 'For $scope' : 'For your Feed',
      ),
      body: widgetAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toUserMessage())),
        data: (existing) {
          _loadFromWidget(existing);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _HowItWorksCard(scope: scope, isGroup: widget.isGroup),
              const SizedBox(height: 16),
              _PreviewCard(
                enabled: _enabled,
                scope: scope,
                time: _time,
                isOwnQuote: _isOwnQuote,
                customText: _textController.text,
                customAuthor: _authorController.text,
                mixAllTopics: _mixAllTopics,
                selectedTopics: _selectedTopics,
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Schedule',
                icon: Icons.schedule_outlined,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show in Feed'),
                    subtitle: Text(
                      _enabled
                          ? 'Quote appears once per day in $scope'
                          : 'Paused — nothing will appear until you turn this on',
                    ),
                    value: _enabled,
                    onChanged: (value) => setState(() => _enabled = value),
                  ),
                  const Divider(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Time of day'),
                    subtitle: Text(formatDailyQuoteSchedule(_time)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickTime,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Timezone'),
                    subtitle: Text(
                      '${deviceTimezoneName()} · matches your device',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'What to show',
                icon: Icons.format_quote_rounded,
                children: [
                  _QuoteOptionTile(
                    title: 'Different quote each day',
                    subtitle:
                        'Tracketiv picks a new quote from our library — you choose the topics',
                    selected: !_isOwnQuote,
                    onTap: () => setState(() => _isOwnQuote = false),
                  ),
                  if (!_isOwnQuote) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Topics',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Use “Mix all topics” for variety, or select specific topics below.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 10),
                    FilterChip(
                      label: const Text('Mix all topics'),
                      selected: _mixAllTopics,
                      onSelected: (selected) {
                        setState(() {
                          _mixAllTopics = selected;
                          if (selected) _selectedTopics = {};
                        });
                      },
                    ),
                    if (!_mixAllTopics) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: FeedQuoteCategory.values.map((topic) {
                          final selected = _selectedTopics.contains(topic);
                          return FilterChip(
                            label: Text(topic.label),
                            selected: selected,
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  _selectedTopics = {..._selectedTopics, topic};
                                } else {
                                  _selectedTopics = _selectedTopics
                                      .where((t) => t != topic)
                                      .toSet();
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      if (_selectedTopics.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Select at least one topic, or turn on Mix all topics.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ),
                    ],
                  ],
                  const SizedBox(height: 8),
                  _QuoteOptionTile(
                    title: 'Always the same quote',
                    subtitle: 'You write it once — we show that exact text every day',
                    selected: _isOwnQuote,
                    onTap: () => setState(() => _isOwnQuote = true),
                  ),
                  if (_isOwnQuote) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        labelText: 'Quote text',
                        hintText: 'e.g. I can do hard things.',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _authorController,
                      decoration: const InputDecoration(
                        labelText: 'Who said it? (optional)',
                        hintText: 'Your name, or leave blank',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              LoadingButton(
                onPressed: _save,
                isLoading: _isLoading,
                label: isInstalling ? 'Install daily quote' : 'Save settings',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard({required this.scope, required this.isGroup});

  final String scope;
  final bool isGroup;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.primaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'How it works',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              isGroup
                  ? 'Once a day, a quote is added to $scope — the same place members see goal updates. It is not a post from anyone; it is an add-on you installed for the group.'
                  : 'Once a day, a quote is added to $scope alongside your posts and friends\' activity. It is not a post from anyone; it is an add-on you installed.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.enabled,
    required this.scope,
    required this.time,
    required this.isOwnQuote,
    required this.customText,
    required this.customAuthor,
    required this.mixAllTopics,
    required this.selectedTopics,
  });

  final bool enabled;
  final String scope;
  final TimeOfDay time;
  final bool isOwnQuote;
  final String customText;
  final String customAuthor;
  final bool mixAllTopics;
  final Set<FeedQuoteCategory> selectedTopics;

  static const _samples = {
    FeedQuoteCategory.goal: 'Small steps every day add up to big change.',
    FeedQuoteCategory.life:
        'The best time to plant a tree was 20 years ago. The second best time is now.',
    FeedQuoteCategory.community:
        'Alone we can do so little; together we can do so much.',
    FeedQuoteCategory.motivation:
        'Believe you can and you\'re halfway there.',
    FeedQuoteCategory.mindfulness: 'Wherever you are, be all there.',
    FeedQuoteCategory.success:
        'Success is liking yourself, liking what you do, and liking how you do it.',
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final previewText = isOwnQuote && customText.trim().isNotEmpty
        ? customText.trim()
        : _samples[selectedTopics.isNotEmpty
            ? selectedTopics.first
            : FeedQuoteCategory.goal]!;
    final previewAuthor = isOwnQuote && customAuthor.trim().isNotEmpty
        ? customAuthor.trim()
        : isOwnQuote
            ? 'You'
            : 'Tracketiv';
    final modeLabel = isOwnQuote
        ? 'Your quote every day'
        : FeedQuoteCategoryX.summaryLabel(selectedTopics, mixAll: mixAllTopics);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preview in Feed',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              enabled
                  ? '${formatDailyQuoteSchedule(time)} · $modeLabel'
                  : 'Turn on “Show in Feed” to see this in $scope',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.format_quote_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Daily quote',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '· Add-on',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    previewText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '— $previewAuthor',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _QuoteOptionTile extends StatelessWidget {
  const _QuoteOptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? colorScheme.primaryContainer.withValues(alpha: 0.45)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? colorScheme.primary : colorScheme.outline,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
