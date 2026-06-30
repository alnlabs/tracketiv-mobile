import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/scaffold_layout.dart';
import '../../../shared/widgets/error_view.dart';
import '../providers/admin_provider.dart';

class AdminConfigScreen extends ConsumerWidget {
  const AdminConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(adminConfigProvider);

    return configAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(error: e,
        onRetry: () => ref.invalidate(adminConfigProvider),
      ),
      data: (config) {
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminConfigProvider),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              listScrollBottomPadding(context),
            ),
            children: [
              Text(
                'App configuration',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Core settings are locked in the database. Admins can view them here but cannot change protected values from the app.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('System admin email'),
                  subtitle: Text(config.systemAdminEmail ?? 'Not configured'),
                  trailing: const Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 16),
              Text('All settings', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...config.settings.entries.map(
                (entry) => Card(
                  child: ListTile(
                    title: Text(entry.key),
                    subtitle: Text(entry.value),
                    trailing: const Icon(Icons.lock_outline),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
