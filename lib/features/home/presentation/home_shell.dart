import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../notifications/providers/notification_provider.dart';
import '../../push/providers/push_provider.dart';
import '../../reminders/providers/reminder_provider.dart';
import '../../auth/providers/session_sync_provider.dart';
import '../../../shared/widgets/offline_banner.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _indexFromLocation(String location) {
    if (location.startsWith('/home/goals')) return 1;
    if (location.startsWith('/home/catalog')) return 2;
    if (location.startsWith('/home/profile')) return 3;
    return 0;
  }

  void _onTap(int index) {
    switch (index) {
      case 0:
        context.go('/home');
      case 1:
        context.go('/home/goals');
      case 2:
        context.go('/home/catalog');
      case 3:
        context.go('/home/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(notificationRealtimeProvider);
    ref.watch(pushRegistrationProvider);
    ref.watch(remindersSyncProvider);
    ref.watch(sessionDataSyncProvider);

    final location = GoRouterState.of(context).uri.toString();
    final index = _indexFromLocation(location);

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: widget.child),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: _onTap,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dynamic_feed_outlined),
            selectedIcon: Icon(Icons.dynamic_feed),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag),
            label: 'Goals',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
