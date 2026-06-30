import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/goal_template.dart';
import '../../../shared/utils/scaffold_layout.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/utils/cadence_utils.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../providers/catalog_filter_provider.dart';
import '../providers/goals_provider.dart';
import '../widgets/catalog_filter_button.dart';
import '../../../shared/widgets/tracketiv_app_bar.dart';
import 'package:tracketiv/shared/utils/api_error_formatter.dart';

/// Browse goal templates. Solo mode by default; group mode requires [groupId].
class GoalCatalogScreen extends ConsumerStatefulWidget {
  const GoalCatalogScreen({super.key, this.initialMode, this.groupId});

  final String? initialMode;
  final String? groupId;

  bool get isGroupMode => groupId != null || initialMode == 'group';

  @override
  ConsumerState<GoalCatalogScreen> createState() => _GoalCatalogScreenState();
}

class _GoalCatalogScreenState extends ConsumerState<GoalCatalogScreen> {
  void _openTemplate(GoalTemplate template) {
    if (widget.isGroupMode && widget.groupId == null) return;
    final params = widget.groupId != null
        ? 'groupId=${widget.groupId}'
        : 'mode=solo';
    context.push('/goals/join/${template.id}?$params', extra: template);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGroupMode && widget.groupId == null) {
      return _PickGroupFirst(onCreateGroup: () => context.push('/groups/create'));
    }

    final category = ref.watch(catalogCategoryFilterProvider);
    final categoryParam = category == 'all' ? null : category;
    final templatesAsync = ref.watch(goalTemplatesProvider(categoryParam));
    final groupAsync = widget.groupId != null
        ? ref.watch(groupDetailProvider(widget.groupId!))
        : null;

    final title = widget.groupId != null ? 'Pick a goal' : 'Explore';

    return Scaffold(
      appBar: TracketivAppBar(
        title: title,
        actions: const [CatalogFilterButton()],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.groupId != null)
            groupAsync?.when(
              data: (group) => Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.groups,
                        size: 18,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Adding to ${group.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: LinearProgressIndicator(minHeight: 3),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ) ??
                const SizedBox.shrink(),
          Expanded(
            child: templatesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(goalTemplatesProvider(categoryParam)),
              ),
              data: (templates) {
                if (templates.isEmpty) {
                  return EmptyState(
                    title: 'No goals found',
                    subtitle: category == 'all'
                        ? 'No templates available.'
                        : 'Try a different category.',
                    actionLabel: category == 'all' ? null : 'Clear filter',
                    onAction: category == 'all'
                        ? null
                        : () => ref.read(catalogCategoryFilterProvider.notifier).state = 'all',
                  );
                }
                return GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    4,
                    12,
                    listScrollBottomPadding(context),
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    mainAxisExtent: 104,
                  ),
                  itemCount: templates.length,
                  itemBuilder: (context, index) {
                    final template = templates[index];
                    return _TemplateCard(
                      template: template,
                      onTap: () => _openTemplate(template),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Solo goal template grid — used in Explore and standalone catalog routes.
class SoloGoalCatalogBody extends ConsumerWidget {
  const SoloGoalCatalogBody({
    super.key,
    this.showHeader = false,
    this.showFilterAction = false,
  });

  final bool showHeader;
  final bool showFilterAction;

  void _openTemplate(BuildContext context, GoalTemplate template) {
    context.push('/goals/join/${template.id}?mode=solo', extra: template);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(catalogCategoryFilterProvider);
    final categoryParam = category == 'all' ? null : category;
    final templatesAsync = ref.watch(goalTemplatesProvider(categoryParam));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Browse templates and start a solo goal.',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                if (showFilterAction) const CatalogFilterButton(),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Goal templates',
                    style: AppTypography.sectionTitle(context),
                  ),
                ),
                const CatalogFilterButton(),
              ],
            ),
          ),
        Expanded(
          child: templatesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(goalTemplatesProvider(categoryParam)),
            ),
            data: (templates) {
              if (templates.isEmpty) {
                return EmptyState(
                  title: 'No goals found',
                  subtitle: category == 'all'
                      ? 'No templates available.'
                      : 'Try a different category.',
                  actionLabel: category == 'all' ? null : 'Clear filter',
                  onAction: category == 'all'
                      ? null
                      : () => ref.read(catalogCategoryFilterProvider.notifier).state = 'all',
                );
              }
              return GridView.builder(
                padding: EdgeInsets.fromLTRB(
                  12,
                  4,
                  12,
                  listScrollBottomPadding(context),
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  mainAxisExtent: 104,
                ),
                itemCount: templates.length,
                itemBuilder: (context, index) {
                  final template = templates[index];
                  return _TemplateCard(
                    template: template,
                    onTap: () => _openTemplate(context, template),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.onTap});

  final GoalTemplate template;
  final VoidCallback onTap;

  String get _categoryLabel {
    final raw = template.category;
    if (raw.isEmpty) return '';
    return raw[0].toUpperCase() + raw.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  iconForTemplate(template),
                  size: 15,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cardTitle(context, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        CadenceUtils.label(template.cadence),
                        if (_categoryLabel.isNotEmpty) _categoryLabel,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (template.description != null &&
                        template.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        template.description!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData iconForTemplate(GoalTemplate template) {
  switch (template.icon) {
    case 'monitor_weight':
      return Icons.monitor_weight_outlined;
    case 'directions_walk':
      return Icons.directions_walk;
    case 'directions_run':
      return Icons.directions_run;
    case 'directions_bike':
      return Icons.directions_bike_outlined;
    case 'water_drop':
      return Icons.water_drop_outlined;
    case 'self_improvement':
      return Icons.self_improvement;
    case 'menu_book':
      return Icons.menu_book;
    case 'book':
      return Icons.book_outlined;
    case 'fitness_center':
      return Icons.fitness_center;
    case 'savings':
      return Icons.savings_outlined;
    case 'account_balance':
      return Icons.account_balance_outlined;
    case 'money_off':
      return Icons.money_off_outlined;
    case 'bedtime':
      return Icons.bedtime_outlined;
    case 'medication':
      return Icons.medication_outlined;
    case 'phone_android':
      return Icons.phone_android_outlined;
    case 'phonelink_off':
      return Icons.phonelink_off_outlined;
    case 'restaurant':
      return Icons.restaurant_outlined;
    case 'no_food':
      return Icons.no_food_outlined;
    case 'edit_note':
      return Icons.edit_note_outlined;
    case 'air':
      return Icons.air_outlined;
    case 'accessibility_new':
      return Icons.accessibility_new_outlined;
    case 'translate':
      return Icons.translate;
    case 'code':
      return Icons.code;
    case 'podcasts':
      return Icons.podcasts;
    case 'alarm':
      return Icons.alarm_outlined;
    case 'timer':
      return Icons.timer_outlined;
    case 'email':
      return Icons.email_outlined;
    case 'cleaning_services':
      return Icons.cleaning_services_outlined;
    default:
      return Icons.flag_outlined;
  }
}

/// Shown when user tries to add a group goal without selecting a group.
class _PickGroupFirst extends ConsumerWidget {
  const _PickGroupFirst({required this.onCreateGroup});

  final VoidCallback onCreateGroup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(myGroupsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: const TracketivAppBar(title: 'Add to a group'),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toUserMessage())),
        data: (groups) {
          if (groups.isEmpty) {
            return EmptyState(
              title: 'No groups yet',
              subtitle: 'Create a group first, invite friends, then add goals together.',
              icon: Icons.groups_outlined,
              actionLabel: 'Create group',
              onAction: onCreateGroup,
            );
          }
          return ListView(
            padding: EdgeInsets.fromLTRB(
              12,
              12,
              12,
              listScrollBottomPadding(context),
            ),
            children: [
              Text(
                'Pick a group for this goal',
                style: AppTypography.sectionTitle(context),
              ),
              const SizedBox(height: 4),
              Text(
                'Everyone in the group tracks it together.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              ...groups.map(
                (group) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.go('/home/catalog?groupId=${group.id}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 16,
                            child: Icon(Icons.groups, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.cardTitle(context, weight: FontWeight.w600),
                                ),
                                Text(
                                  '${group.goalCount ?? 0} goal${(group.goalCount ?? 0) == 1 ? '' : 's'}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: onCreateGroup,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create new group'),
              ),
            ],
          );
        },
      ),
    );
  }
}
