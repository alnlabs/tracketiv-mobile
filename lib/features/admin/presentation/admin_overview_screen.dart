import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/scaffold_layout.dart';
import '../../../shared/widgets/error_view.dart';
import '../providers/admin_provider.dart';

class AdminOverviewScreen extends ConsumerWidget {
  const AdminOverviewScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminDashboardProvider);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(error: e,
        onRetry: () => ref.invalidate(adminDashboardProvider),
      ),
      data: (stats) {
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminDashboardProvider),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              listScrollBottomPadding(context),
            ),
            children: [
              Text(
                'Management overview',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Admin accounts manage users, default app data, feedback, and configuration. They do not use the user app.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              _StatCard(
                icon: Icons.people_outline,
                title: 'Users',
                value: '${stats.usersTotal}',
                subtitle: stats.usersDeleted > 0 ? '${stats.usersDeleted} soft-deleted' : 'Registered accounts',
                onTap: () => onNavigate(1),
              ),
              _StatCard(
                icon: Icons.flag_outlined,
                title: 'Goal templates',
                value: '${stats.templatesTotal}',
                subtitle: 'Default catalog data',
                onTap: () => onNavigate(2),
              ),
              _StatCard(
                icon: Icons.feedback_outlined,
                title: 'Feedback',
                value: '${stats.feedbackTotal}',
                subtitle: 'User submissions',
                onTap: () => onNavigate(3),
              ),
              _StatCard(
                icon: Icons.bug_report_outlined,
                title: 'Crashes',
                value: '${stats.crashesTotal}',
                subtitle: stats.crashes24h > 0
                    ? '${stats.crashes24h} in the last 24 hours'
                    : 'Error reports from the app',
                onTap: () => onNavigate(4),
              ),
              _StatCard(
                icon: Icons.settings_outlined,
                title: 'Configuration',
                value: '${stats.goalsTotal} goals',
                subtitle: '${stats.groupsTotal} groups in the system',
                onTap: () => onNavigate(5),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
