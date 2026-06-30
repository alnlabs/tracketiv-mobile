import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/feed_widget.dart';
import '../../../shared/utils/feed_widget_time.dart';
import '../../../shared/utils/scaffold_layout.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../providers/feed_provider.dart';
import '../providers/feed_widget_provider.dart';

/// Installed feed add-ons — used in Explore and standalone screen.
class FeedWidgetsBody extends ConsumerWidget {
  const FeedWidgetsBody({super.key});

  static const _dailyQuoteAddon = _AvailableAddon(
    id: 'quote',
    title: 'Daily quote',
    description:
        'One motivational quote in your Feed each morning — sits with posts, not from a person',
    icon: Icons.format_quote_rounded,
    personalRoute: '/feed/widgets/personal/quote',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final widgetsAsync = ref.watch(myFeedWidgetsProvider);

    return widgetsAsync.when(
      loading: () => ListView(
        padding: EdgeInsets.only(bottom: fabScrollBottomPadding(context)),
        children: const [
          _AddonsIntro(),
          SizedBox(height: 48),
          Center(child: CircularProgressIndicator()),
        ],
      ),
      error: (error, _) => ListView(
        padding: EdgeInsets.only(bottom: fabScrollBottomPadding(context)),
        children: [
          const _AddonsIntro(),
          ErrorView(
            error: error,
            onRetry: () => ref.invalidate(myFeedWidgetsProvider),
          ),
        ],
      ),
      data: (widgets) {
        final hasPersonalQuote = widgets.any(
          (w) => w.isPersonal && w.widgetType == FeedWidgetType.quote,
        );

        if (widgets.isEmpty) {
          return ListView(
            padding: EdgeInsets.only(bottom: fabScrollBottomPadding(context)),
            children: [
              const _AddonsIntro(),
              _AvailableAddonCard(
                addon: _dailyQuoteAddon,
                installed: false,
              ),
              const SizedBox(height: 16),
              EmptyState(
                title: 'No add-ons installed yet',
                subtitle:
                    'Install extras that help you stay motivated. Daily quote is available now — more coming soon.',
                icon: Icons.extension_outlined,
                actionLabel: 'Install daily quote',
                onAction: () => context.push(_dailyQuoteAddon.personalRoute),
              ),
            ],
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myFeedWidgetsProvider);
            ref.invalidate(feedProvider);
          },
          child: ListView(
            padding: EdgeInsets.only(bottom: fabScrollBottomPadding(context)),
            children: [
              const _AddonsIntro(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Installed',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              ...widgets.map(_InstalledAddonTile.new),
              if (!hasPersonalQuote) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Available to install',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                _AvailableAddonCard(
                  addon: _dailyQuoteAddon,
                  installed: false,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _InstalledAddonTile extends StatelessWidget {
  const _InstalledAddonTile(this.widget);

  final FeedWidget widget;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        widget.widgetType == FeedWidgetType.quote
            ? Icons.format_quote_rounded
            : Icons.extension_outlined,
      ),
      title: Text(widget.title),
      subtitle: Text(
        widget.enabled
            ? '${formatDailyQuoteScheduleFromStorage(widget.showTime)} · ${widget.config.topicsSummary}'
            : 'Paused · ${widget.config.topicsSummary}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        if (widget.isPersonal) {
          context.push('/feed/widgets/personal/quote');
        } else if (widget.groupId != null) {
          context.push('/feed/widgets/group/${widget.groupId}/quote');
        }
      },
    );
  }
}

class _AddonsIntro extends StatelessWidget {
  const _AddonsIntro();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        'Add-ons are optional extras you install for your feed — not phone home-screen widgets. '
        'More add-ons will appear here over time.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _AvailableAddon {
  const _AvailableAddon({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.personalRoute,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String personalRoute;
}

class _AvailableAddonCard extends StatelessWidget {
  const _AvailableAddonCard({
    required this.addon,
    required this.installed,
  });

  final _AvailableAddon addon;
  final bool installed;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: installed ? null : () => context.push(addon.personalRoute),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(addon.icon, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      addon.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      addon.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (installed)
                Icon(
                  Icons.check_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                )
              else
                FilledButton(
                  onPressed: () => context.push(addon.personalRoute),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Install'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
