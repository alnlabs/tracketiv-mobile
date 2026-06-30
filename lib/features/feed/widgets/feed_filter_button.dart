import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/filter_pill.dart';
import '../models/feed_date_filter.dart';
import '../providers/feed_date_filter_provider.dart';
import '../providers/feed_provider.dart';

class FeedFilterButton extends ConsumerWidget {
  const FeedFilterButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(feedFiltersProvider);
    final dateFilter = ref.watch(feedDateFilterProvider);
    final count = filters.length + (dateFilter.countsAsActiveFilter ? 1 : 0);

    return IconButton(
      tooltip: count == 0 ? 'Filter feed' : 'Filters ($count)',
      onPressed: () => showFeedFilterSheet(context, ref),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.filter_list_rounded),
      ),
    );
  }
}

Future<void> showFeedFilterSheet(BuildContext context, WidgetRef ref) async {
  final selected = Set<FeedFilterOption>.from(ref.read(feedFiltersProvider));
  var dateFilter = ref.read(feedDateFilterProvider);

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final appliedCount =
              selected.length + (dateFilter.countsAsActiveFilter ? 1 : 0);

          Future<void> pickRange() async {
            final now = FeedDateFilter.dateOnly(DateTime.now());
            final initialStart =
                dateFilter.rangeStart ?? FeedDateFilter.defaultRangeStart();
            final initialEnd = dateFilter.rangeEnd ?? now;
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(now.year - 2),
              lastDate: now,
              initialDateRange: DateTimeRange(
                start: initialStart.isAfter(now) ? now : initialStart,
                end: initialEnd.isAfter(now) ? now : initialEnd,
              ),
            );
            if (picked == null) return;
            setSheetState(() {
              dateFilter = FeedDateFilter.range(
                start: picked.start,
                end: picked.end,
              );
            });
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Filter feed',
                          style: AppTypography.sheetTitle(context),
                        ),
                      ),
                      if (appliedCount > 0)
                        TextButton(
                          onPressed: () => setSheetState(() {
                            selected.clear();
                            dateFilter = FeedDateFilter.today();
                          }),
                          child: const Text('Reset'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appliedCount == 0
                        ? 'Showing today\'s activity'
                        : '$appliedCount filter${appliedCount == 1 ? '' : 's'} applied',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Date',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterPill(
                        label: 'Today',
                        selected: dateFilter.mode == FeedDateFilterMode.today,
                        onTap: () => setSheetState(
                          () => dateFilter = FeedDateFilter.today(),
                        ),
                      ),
                      FilterPill(
                        label: 'Range',
                        selected: dateFilter.mode == FeedDateFilterMode.range,
                        onTap: () async {
                          if (dateFilter.mode != FeedDateFilterMode.range) {
                            setSheetState(() {
                              dateFilter = FeedDateFilter.range(
                                start: FeedDateFilter.defaultRangeStart(),
                                end: FeedDateFilter.dateOnly(DateTime.now()),
                              );
                            });
                          }
                          await pickRange();
                        },
                      ),
                      FilterPill(
                        label: 'All',
                        selected: dateFilter.mode == FeedDateFilterMode.all,
                        onTap: () => setSheetState(
                          () => dateFilter = FeedDateFilter.all(),
                        ),
                      ),
                    ],
                  ),
                  if (dateFilter.mode == FeedDateFilterMode.range) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: pickRange,
                      icon: const Icon(Icons.date_range_outlined, size: 18),
                      label: Text(
                        _rangeButtonLabel(dateFilter),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'Activity',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: FeedFilterOption.values.map((option) {
                      final isSelected = selected.contains(option);
                      return FilterPill(
                        label: option.label,
                        selected: isSelected,
                        onTap: () {
                          setSheetState(() {
                            if (isSelected) {
                              selected.remove(option);
                            } else {
                              selected.add(option);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () async {
                      ref.read(feedFiltersProvider.notifier).state =
                          Set<FeedFilterOption>.from(selected);
                      await ref
                          .read(feedDateFilterProvider.notifier)
                          .setFilter(dateFilter);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

String _rangeButtonLabel(FeedDateFilter filter) {
  final start = filter.rangeStart;
  final end = filter.rangeEnd;
  if (start == null || end == null) return 'Pick date range';
  final fmt = DateFormat.MMMd();
  if (start == end) return fmt.format(start);
  return '${fmt.format(start)} – ${fmt.format(end)}';
}
