import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/utils/scaffold_layout.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/filter_pill.dart';
import '../providers/admin_provider.dart';

class AdminCrashesScreen extends ConsumerStatefulWidget {
  const AdminCrashesScreen({super.key});

  @override
  ConsumerState<AdminCrashesScreen> createState() => _AdminCrashesScreenState();
}

class _AdminCrashesScreenState extends ConsumerState<AdminCrashesScreen> {
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    final crashesAsync = ref.watch(adminCrashesProvider);

    return crashesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(error: e,
        onRetry: () => ref.invalidate(adminCrashesProvider),
      ),
      data: (crashes) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Crash reports',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Expanded(
              child: crashes.isEmpty
                  ? const Center(child: Text('No crashes reported yet'))
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(adminCrashesProvider);
                        ref.invalidate(adminDashboardProvider);
                      },
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          listScrollBottomPadding(context),
                        ),
                        itemCount: crashes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final crash = crashes[index];
                          final expanded = _expandedId == crash.id;
                          return Card(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => setState(() {
                                _expandedId = expanded ? null : crash.id;
                              }),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            crash.message,
                                            maxLines: expanded ? null : 2,
                                            overflow: expanded ? null : TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        InfoPill(label: crash.sourceLabel),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      [
                                        crash.errorType,
                                        if (crash.platform != null) crash.platform!,
                                        if (crash.route != null) crash.route!,
                                        DateFormat.yMMMd().add_jm().format(crash.createdAt),
                                      ].join(' · '),
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                    if (crash.userEmail != null || crash.userName != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        crash.userEmail ?? crash.userName!,
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                    if (expanded && crash.stackTrace != null) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          crash.stackTrace!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(fontFamily: 'monospace'),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
