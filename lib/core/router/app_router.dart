import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/presentation/admin_login_screen.dart';
import '../../features/admin/presentation/admin_verify_otp_screen.dart';
import '../../features/admin/presentation/admin_shell.dart';
import '../../features/legal/presentation/legal_screens.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/onboarding/providers/onboarding_provider.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/explore/presentation/explore_screen.dart';
import '../../features/feed/presentation/edit_feed_quote_widget_screen.dart';
import '../../features/feed/presentation/feed_post_detail_screen.dart';
import '../../features/feed/presentation/feed_screen.dart';
import '../../features/feed/presentation/feed_widgets_screen.dart';
import '../../features/goals/presentation/create_group_screen.dart';
import '../../features/goals/presentation/goal_catalog_screen.dart';
import '../../features/goals/presentation/group_detail_screen.dart';
import '../../features/goals/presentation/group_members_screen.dart';
import '../../features/goals/presentation/goal_group_members_screen.dart';
import '../../features/goals/presentation/edit_goal_screen.dart';
import '../../features/goals/presentation/goal_detail_screen.dart';
import '../../features/goals/presentation/join_goal_screen.dart';
import '../../features/goals/presentation/my_goals_screen.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/logs/presentation/add_log_screen.dart';
import '../../shared/models/post_type.dart';
import '../../features/feedback/presentation/feedback_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/user_profile_screen.dart';
import '../../features/reminders/presentation/reminder_settings_screen.dart';
import '../../shared/models/goal_template.dart';
import '../crash/crash_reporter.dart';
import 'app_router_notifier.dart';

String resolveInitialLocation(Ref ref) {
  final onboardingDone = ref.read(onboardingCompletedProvider).valueOrNull ?? false;
  final hasSession = ref.read(supabaseClientProvider).auth.currentSession != null;
  if (hasSession) return '/home';
  return onboardingDone ? '/login' : '/onboarding';
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.read(appRouterNotifierProvider);

  final router = GoRouter(
    initialLocation: resolveInitialLocation(ref),
    refreshListenable: notifier,
    redirect: (context, state) => notifier.redirect(state),
    observers: [CrashRouteObserver()],
    routes: [
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
      GoRoute(path: '/disclaimer', builder: (_, __) => const DisclaimerScreen()),
      GoRoute(path: '/privacy-policy', builder: (_, __) => const PrivacyPolicyScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/reset-password', builder: (_, __) => const ResetPasswordScreen()),
      ShellRoute(
        builder: (_, __, child) => AdminShell(child: child),
        routes: [
          GoRoute(path: '/admin/login', builder: (_, __) => const AdminLoginScreen()),
          GoRoute(path: '/admin/verify-otp', builder: (_, __) => const AdminVerifyOtpScreen()),
          GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardScreen()),
        ],
      ),
      ShellRoute(
        builder: (_, __, child) => HomeShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const FeedScreen()),
          GoRoute(path: '/home/goals', builder: (_, __) => const MyGoalsScreen()),
          GoRoute(
            path: '/home/catalog',
            builder: (_, state) {
              final groupId = state.uri.queryParameters['groupId'];
              final mode = state.uri.queryParameters['mode'];
              if (groupId != null || mode == 'group') {
                return GoalCatalogScreen(initialMode: mode, groupId: groupId);
              }
              return const ExploreScreen();
            },
          ),
          GoRoute(path: '/home/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/feedback',
        builder: (_, __) => const FeedbackScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/feed/widgets',
        builder: (_, __) => const FeedWidgetsScreen(),
      ),
      GoRoute(
        path: '/feed/widgets/personal/quote',
        builder: (_, __) => const EditFeedQuoteWidgetScreen(),
      ),
      GoRoute(
        path: '/feed/widgets/group/:groupId/quote',
        builder: (_, state) => EditFeedQuoteWidgetScreen(
          groupId: state.pathParameters['groupId'],
        ),
      ),
      GoRoute(
        path: '/feed/posts/:logId',
        builder: (_, state) => FeedPostDetailScreen(
          logId: state.pathParameters['logId']!,
        ),
      ),
      GoRoute(
        path: '/users/:userId',
        builder: (_, state) => UserProfileScreen(userId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: '/groups/create',
        builder: (_, __) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: '/groups/:groupId',
        builder: (_, state) => GroupDetailScreen(groupId: state.pathParameters['groupId']!),
      ),
      GoRoute(
        path: '/groups/:groupId/members',
        builder: (_, state) => GroupMembersScreen(groupId: state.pathParameters['groupId']!),
      ),
      GoRoute(
        path: '/goals/join/:templateId',
        builder: (context, state) {
          final template = state.extra as GoalTemplate?;
          if (template == null) {
            return const Scaffold(body: Center(child: Text('Template not found')));
          }
          return JoinGoalScreen(
            template: template,
            groupId: state.uri.queryParameters['groupId'],
          );
        },
      ),
      GoRoute(
        path: '/goals/:goalId',
        builder: (_, state) => GoalDetailScreen(goalId: state.pathParameters['goalId']!),
      ),
      GoRoute(
        path: '/goals/:goalId/log',
        builder: (_, state) => AddLogScreen(
          goalId: state.pathParameters['goalId']!,
          postType: PostType.fromQuery(state.uri.queryParameters['type']) ?? PostType.metric,
        ),
      ),
      GoRoute(
        path: '/goals/:goalId/edit',
        builder: (_, state) => EditGoalScreen(goalId: state.pathParameters['goalId']!),
      ),
      GoRoute(
        path: '/goals/:goalId/reminder',
        builder: (_, state) => ReminderSettingsScreen(goalId: state.pathParameters['goalId']!),
      ),
      GoRoute(
        path: '/goals/:goalId/members',
        builder: (_, state) => GoalGroupMembersScreen(goalId: state.pathParameters['goalId']!),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
