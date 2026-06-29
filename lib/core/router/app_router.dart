import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/goals/presentation/goal_catalog_screen.dart';
import '../../features/goals/presentation/goal_detail_screen.dart';
import '../../features/goals/presentation/join_goal_screen.dart';
import '../../features/goals/presentation/my_goals_screen.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/logs/presentation/add_log_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/reminders/presentation/reminder_settings_screen.dart';
import '../../shared/models/goal_template.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      final isLoggedIn = authState.valueOrNull?.session != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password' ||
          state.matchedLocation == '/reset-password';

      if (isLoading) return null;

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute && state.matchedLocation != '/reset-password') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/reset-password', builder: (_, __) => const ResetPasswordScreen()),
      ShellRoute(
        builder: (_, __, child) => HomeShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const MyGoalsScreen()),
          GoRoute(path: '/home/catalog', builder: (_, __) => const GoalCatalogScreen()),
          GoRoute(path: '/home/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/goals/join/:templateId',
        builder: (context, state) {
          final template = state.extra as GoalTemplate?;
          if (template == null) {
            return const Scaffold(body: Center(child: Text('Template not found')));
          }
          return JoinGoalScreen(template: template);
        },
      ),
      GoRoute(
        path: '/goals/:goalId',
        builder: (_, state) => GoalDetailScreen(goalId: state.pathParameters['goalId']!),
      ),
      GoRoute(
        path: '/goals/:goalId/log',
        builder: (_, state) => AddLogScreen(goalId: state.pathParameters['goalId']!),
      ),
      GoRoute(
        path: '/goals/:goalId/reminder',
        builder: (_, state) => ReminderSettingsScreen(goalId: state.pathParameters['goalId']!),
      ),
    ],
  );
});
