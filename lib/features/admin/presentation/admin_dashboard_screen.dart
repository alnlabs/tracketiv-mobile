import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/admin_auth_provider.dart';
import '../providers/admin_otp_provider.dart';
import '../providers/admin_session_provider.dart';
import 'admin_config_screen.dart';
import 'admin_crashes_screen.dart';
import 'admin_feedback_screen.dart';
import 'admin_overview_screen.dart';
import 'admin_templates_screen.dart';
import 'admin_users_screen.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _index = 0;

  static const _destinations = [
    (icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Overview'),
    (icon: Icons.people_outline, selectedIcon: Icons.people, label: 'Users'),
    (icon: Icons.flag_outlined, selectedIcon: Icons.flag, label: 'Default data'),
    (icon: Icons.feedback_outlined, selectedIcon: Icons.feedback, label: 'Feedback'),
    (icon: Icons.bug_report_outlined, selectedIcon: Icons.bug_report, label: 'Crashes'),
    (icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Configuration'),
  ];

  String get _title => _destinations[_index].label;

  Future<void> _signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    await ref.read(adminSessionActiveProvider.notifier).deactivate();
    await ref.read(adminOtpPendingProvider.notifier).clear();
    ref.invalidate(currentProfileProvider);
    if (mounted) context.go('/admin/login');
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(adminCurrentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_title),
            profileAsync.when(
              data: (profile) => Text(
                profile?.publicName ?? 'Admin',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.85),
                    ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      drawer: NavigationDrawer(
        selectedIndex: _index,
        onDestinationSelected: (index) {
          setState(() => _index = index);
          Navigator.pop(context);
        },
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 16, 16),
            child: Text(
              'Tracketiv Admin',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: Text('Management console only'),
          ),
          const SizedBox(height: 16),
          ...List.generate(_destinations.length, (index) {
            final dest = _destinations[index];
            return NavigationDrawerDestination(
              icon: Icon(dest.icon),
              selectedIcon: Icon(dest.selectedIcon),
              label: Text(dest.label),
            );
          }),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: _signOut,
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          AdminOverviewScreen(onNavigate: (index) => setState(() => _index = index)),
          const AdminUsersScreen(),
          const AdminTemplatesScreen(),
          const AdminFeedbackScreen(),
          const AdminCrashesScreen(),
          const AdminConfigScreen(),
        ],
      ),
    );
  }
}
