import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/filter_pill.dart';
import '../providers/catalog_filter_provider.dart';

class CatalogFilterButton extends ConsumerWidget {
  const CatalogFilterButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(catalogCategoryFilterProvider);
    final isFiltered = category != 'all';

    return IconButton(
      tooltip: isFiltered ? 'Category: ${catalogCategoryLabels[category]}' : 'Filter templates',
      onPressed: () => showCatalogFilterSheet(context, ref),
      icon: Badge(
        isLabelVisible: isFiltered,
        label: const Text('1'),
        child: const Icon(Icons.filter_list_rounded),
      ),
    );
  }
}

Future<void> showCatalogFilterSheet(BuildContext context, WidgetRef ref) async {
  var selected = ref.read(catalogCategoryFilterProvider);

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final isFiltered = selected != 'all';

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Filter templates',
                          style: AppTypography.sheetTitle(context),
                        ),
                      ),
                      if (isFiltered)
                        TextButton(
                          onPressed: () => setSheetState(() => selected = 'all'),
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isFiltered
                        ? catalogCategoryLabels[selected]!
                        : 'Showing all categories',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: catalogCategoryLabels.entries.map((entry) {
                      final isSelected = selected == entry.key;
                      return FilterPill(
                        label: entry.value,
                        selected: isSelected,
                        onTap: () => setSheetState(() => selected = entry.key),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      ref.read(catalogCategoryFilterProvider.notifier).state = selected;
                      Navigator.pop(context);
                    },
                    child: Text(isFiltered ? 'Apply filter' : 'Show all'),
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
