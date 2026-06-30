import 'package:tracketiv/shared/models/goal_template.dart';

import '../integration/supabase_test_config.dart';
import 'e2e_bootstrap.dart';

sealed class E2eExpectation {
  const E2eExpectation();
}

class E2eShowsText extends E2eExpectation {
  const E2eShowsText(this.text);
  final String text;
}

class E2eShowsAnyText extends E2eExpectation {
  const E2eShowsAnyText(this.texts);
  final List<String> texts;
}

class E2eRedirect extends E2eExpectation {
  const E2eRedirect(this.pathPrefix);
  final String pathPrefix;
}

class E2eScreen {
  const E2eScreen({
    required this.id,
    required this.path,
    required this.expectations,
    this.extra,
  });

  final String id;
  final String path;
  final Object? extra;
  final Map<E2eRole, E2eExpectation> expectations;

  E2eExpectation? forRole(E2eRole role) => expectations[role];
}

GoalTemplate get e2eJoinTemplate => const GoalTemplate(
      id: SupabaseTestConfig.templateId,
      title: SupabaseTestConfig.templateTitle,
      description: 'Template for end-to-end join-goal screen tests.',
      category: 'fitness',
      metricType: 'steps',
      metricUnit: 'steps',
      cadence: 'daily',
      defaultTarget: {'target_value': 5000},
      icon: 'directions_walk',
    );

const _auth = {
  E2eRole.guest: E2eRedirect('/login'),
  E2eRole.outsider: E2eRedirect('/login'),
  E2eRole.member: E2eRedirect('/login'),
  E2eRole.owner: E2eRedirect('/login'),
  E2eRole.admin: E2eRedirect('/admin'),
};

const _homeTabs = {
  E2eRole.guest: E2eRedirect('/login'),
  E2eRole.outsider: E2eShowsText('Feed'),
  E2eRole.member: E2eShowsText('Feed'),
  E2eRole.owner: E2eShowsText('Feed'),
  E2eRole.admin: E2eRedirect('/admin'),
};

const _goalReadable = {
  E2eRole.guest: E2eRedirect('/login'),
  E2eRole.outsider: E2eShowsAnyText(['Test Running Goal', 'Goal', 'Something went wrong']),
  E2eRole.member: E2eShowsAnyText(['Test Running Goal', 'Goal', 'Something went wrong']),
  E2eRole.owner: E2eShowsAnyText(['Test Running Goal', 'Goal', 'Something went wrong']),
  E2eRole.admin: E2eRedirect('/admin'),
};

const _groupReadable = {
  E2eRole.guest: E2eRedirect('/login'),
  E2eRole.outsider: E2eShowsAnyText([SupabaseTestConfig.groupName, 'Group', 'Something went wrong']),
  E2eRole.member: E2eShowsAnyText([SupabaseTestConfig.groupName, 'Group', 'Something went wrong']),
  E2eRole.owner: E2eShowsAnyText([SupabaseTestConfig.groupName, 'Group', 'Something went wrong']),
  E2eRole.admin: E2eRedirect('/admin'),
};

/// Every routed screen in [app_router.dart] with per-role expectations.
final List<E2eScreen> e2eScreenCatalog = [
  E2eScreen(
    id: 'onboarding',
    path: '/onboarding',
    expectations: {
      E2eRole.guest: E2eRedirect('/login'),
      E2eRole.outsider: E2eRedirect('/home'),
      E2eRole.member: E2eRedirect('/home'),
      E2eRole.owner: E2eRedirect('/home'),
      E2eRole.admin: E2eRedirect('/admin'),
    },
  ),
  E2eScreen(
    id: 'about',
    path: '/about',
    expectations: {
      E2eRole.guest: E2eShowsText('About'),
      E2eRole.outsider: E2eShowsText('About'),
      E2eRole.member: E2eShowsText('About'),
      E2eRole.owner: E2eShowsText('About'),
      E2eRole.admin: E2eRedirect('/admin'),
    },
  ),
  E2eScreen(
    id: 'disclaimer',
    path: '/disclaimer',
    expectations: {
      E2eRole.guest: E2eShowsText('Disclaimer'),
      E2eRole.outsider: E2eShowsText('Disclaimer'),
      E2eRole.member: E2eShowsText('Disclaimer'),
      E2eRole.owner: E2eShowsText('Disclaimer'),
      E2eRole.admin: E2eRedirect('/admin'),
    },
  ),
  E2eScreen(
    id: 'privacy',
    path: '/privacy-policy',
    expectations: {
      E2eRole.guest: E2eShowsText('Privacy Policy'),
      E2eRole.outsider: E2eShowsText('Privacy Policy'),
      E2eRole.member: E2eShowsText('Privacy Policy'),
      E2eRole.owner: E2eShowsText('Privacy Policy'),
      E2eRole.admin: E2eRedirect('/admin'),
    },
  ),
  E2eScreen(
    id: 'login',
    path: '/login',
    expectations: {
      E2eRole.guest: E2eShowsText('Track habits. Achieve goals. Together.'),
      E2eRole.outsider: E2eRedirect('/home'),
      E2eRole.member: E2eRedirect('/home'),
      E2eRole.owner: E2eRedirect('/home'),
      E2eRole.admin: E2eRedirect('/admin'),
    },
  ),
  E2eScreen(
    id: 'register',
    path: '/register',
    expectations: {
      E2eRole.guest: E2eShowsText('Create account'),
      E2eRole.outsider: E2eRedirect('/home'),
      E2eRole.member: E2eRedirect('/home'),
      E2eRole.owner: E2eRedirect('/home'),
      E2eRole.admin: E2eRedirect('/admin'),
    },
  ),
  E2eScreen(
    id: 'forgot_password',
    path: '/forgot-password',
    expectations: {
      E2eRole.guest: E2eShowsText('Forgot password'),
      E2eRole.outsider: E2eRedirect('/home'),
      E2eRole.member: E2eRedirect('/home'),
      E2eRole.owner: E2eRedirect('/home'),
      E2eRole.admin: E2eRedirect('/admin'),
    },
  ),
  E2eScreen(
    id: 'reset_password',
    path: '/reset-password',
    expectations: {
      E2eRole.guest: E2eShowsText('Reset password'),
      E2eRole.outsider: E2eShowsText('Reset password'),
      E2eRole.member: E2eShowsText('Reset password'),
      E2eRole.owner: E2eShowsText('Reset password'),
      E2eRole.admin: E2eRedirect('/admin'),
    },
  ),
  E2eScreen(
    id: 'admin_login',
    path: '/admin/login',
    expectations: {
      E2eRole.guest: E2eShowsText('Tracketiv Admin'),
      E2eRole.outsider: E2eShowsText('Tracketiv Admin'),
      E2eRole.member: E2eShowsText('Tracketiv Admin'),
      E2eRole.owner: E2eShowsText('Tracketiv Admin'),
      E2eRole.admin: E2eRedirect('/admin'),
    },
  ),
  E2eScreen(
    id: 'admin_dashboard',
    path: '/admin',
    expectations: {
      E2eRole.guest: E2eRedirect('/admin/login'),
      E2eRole.outsider: E2eRedirect('/admin/login'),
      E2eRole.member: E2eRedirect('/admin/login'),
      E2eRole.owner: E2eRedirect('/admin/login'),
      E2eRole.admin: E2eShowsText('Overview'),
    },
  ),
  E2eScreen(
    id: 'home_feed',
    path: '/home',
    expectations: _homeTabs,
  ),
  E2eScreen(
    id: 'home_goals',
    path: '/home/goals',
    expectations: {
      E2eRole.guest: E2eRedirect('/login'),
      E2eRole.outsider: E2eShowsText('My Goals'),
      E2eRole.member: E2eShowsText('My Goals'),
      E2eRole.owner: E2eShowsText('My Goals'),
      E2eRole.admin: E2eRedirect('/admin'),
    },
  ),
  E2eScreen(
    id: 'home_catalog',
    path: '/home/catalog',
    expectations: {
      E2eRole.guest: E2eRedirect('/login'),
      E2eRole.outsider: E2eShowsAnyText(['Explore', 'Connect', 'Add-ons']),
      E2eRole.member: E2eShowsAnyText(['Explore', 'Connect', 'Add-ons']),
      E2eRole.owner: E2eShowsAnyText(['Explore', 'Connect', 'Add-ons']),
      E2eRole.admin: E2eRedirect('/admin'),
    },
  ),
  E2eScreen(
    id: 'home_catalog_group_picker',
    path: '/home/catalog?mode=group',
    expectations: {
      E2eRole.guest: E2eRedirect('/login'),
      E2eRole.outsider: E2eShowsText('Add to a group'),
      E2eRole.member: E2eShowsText('Add to a group'),
      E2eRole.owner: E2eShowsText('Add to a group'),
      E2eRole.admin: E2eRedirect('/admin'),
    },
  ),
  E2eScreen(
    id: 'home_profile',
    path: '/home/profile',
    expectations: {
      E2eRole.guest: E2eRedirect('/login'),
      E2eRole.outsider: E2eShowsText('Profile'),
      E2eRole.member: E2eShowsText('Profile'),
      E2eRole.owner: E2eShowsText('Profile'),
      E2eRole.admin: E2eRedirect('/admin'),
    },
  ),
  E2eScreen(
    id: 'feedback',
    path: '/feedback',
    expectations: {
      E2eRole.guest: _auth[E2eRole.guest]!,
      E2eRole.outsider: E2eShowsText('Send feedback'),
      E2eRole.member: E2eShowsText('Send feedback'),
      E2eRole.owner: E2eShowsText('Send feedback'),
      E2eRole.admin: E2eRedirect('/admin'),
    },
  ),
  E2eScreen(
    id: 'notifications',
    path: '/notifications',
    expectations: {
      E2eRole.guest: _auth[E2eRole.guest]!,
      E2eRole.outsider: E2eShowsText('Notifications'),
      E2eRole.member: E2eShowsText('Notifications'),
      E2eRole.owner: E2eShowsText('Notifications'),
      E2eRole.admin: E2eRedirect('/admin'),
    },
  ),
  E2eScreen(
    id: 'feed_post_detail',
    path: '/feed/posts/${SupabaseTestConfig.seedLogId}',
    expectations: {
      E2eRole.guest: _auth[E2eRole.guest]!,
      E2eRole.outsider: E2eShowsAnyText(['Post', 'Something went wrong']),
      E2eRole.member: E2eShowsText('Post'),
      E2eRole.owner: E2eShowsText('Post'),
      E2eRole.admin: E2eRedirect('/admin'),
    },
  ),
  E2eScreen(
    id: 'user_profile',
    path: '/users/${SupabaseTestConfig.memberId}',
    expectations: {
      E2eRole.guest: _auth[E2eRole.guest]!,
      E2eRole.outsider: E2eShowsAnyText(['Test Member', 'Profile']),
      E2eRole.member: E2eShowsAnyText(['Test Member', 'Profile']),
      E2eRole.owner: E2eShowsAnyText(['Test Member', 'Profile']),
      E2eRole.admin: E2eRedirect('/admin'),
    },
  ),
  E2eScreen(
    id: 'create_group',
    path: '/groups/create',
    expectations: {
      E2eRole.guest: _auth[E2eRole.guest]!,
      E2eRole.outsider: E2eShowsText('Create group'),
      E2eRole.member: E2eShowsText('Create group'),
      E2eRole.owner: E2eShowsText('Create group'),
      E2eRole.admin: E2eRedirect('/admin'),
    },
  ),
  E2eScreen(
    id: 'group_detail',
    path: '/groups/${SupabaseTestConfig.groupId}',
    expectations: _groupReadable,
  ),
  E2eScreen(
    id: 'group_members',
    path: '/groups/${SupabaseTestConfig.groupId}/members',
    expectations: {
      E2eRole.guest: _auth[E2eRole.guest]!,
      E2eRole.outsider: E2eShowsAnyText(['Members', 'Something went wrong']),
      E2eRole.member: E2eShowsText('Members'),
      E2eRole.owner: E2eShowsText('Members'),
      E2eRole.admin: E2eRedirect('/admin'),
    },
  ),
  E2eScreen(
    id: 'join_goal',
    path: '/goals/join/${SupabaseTestConfig.templateId}?mode=solo',
    extra: e2eJoinTemplate,
    expectations: {
      E2eRole.guest: _auth[E2eRole.guest]!,
      E2eRole.outsider: E2eShowsText(SupabaseTestConfig.templateTitle),
      E2eRole.member: E2eShowsText(SupabaseTestConfig.templateTitle),
      E2eRole.owner: E2eShowsText(SupabaseTestConfig.templateTitle),
      E2eRole.admin: E2eRedirect('/admin'),
    },
  ),
  E2eScreen(
    id: 'goal_detail',
    path: '/goals/${SupabaseTestConfig.goalId}',
    expectations: _goalReadable,
  ),
  E2eScreen(
    id: 'group_goal_detail',
    path: '/goals/${SupabaseTestConfig.groupGoalId}',
    expectations: {
      E2eRole.guest: _auth[E2eRole.guest]!,
      E2eRole.outsider: E2eShowsAnyText([SupabaseTestConfig.groupGoalTitle, 'Goal']),
      E2eRole.member: E2eShowsAnyText([SupabaseTestConfig.groupGoalTitle, 'Goal', 'Something went wrong']),
      E2eRole.owner: E2eShowsAnyText([SupabaseTestConfig.groupGoalTitle, 'Goal', 'Something went wrong']),
      E2eRole.admin: E2eRedirect('/admin'),
    },
  ),
  E2eScreen(
    id: 'add_log',
    path: '/goals/${SupabaseTestConfig.goalId}/log',
    expectations: {
      E2eRole.guest: _auth[E2eRole.guest]!,
      E2eRole.outsider: E2eShowsAnyText(['Log progress', 'Something went wrong']),
      E2eRole.member: E2eShowsText('Log progress'),
      E2eRole.owner: E2eShowsText('Log progress'),
      E2eRole.admin: E2eRedirect('/admin'),
    },
  ),
  E2eScreen(
    id: 'edit_goal',
    path: '/goals/${SupabaseTestConfig.goalId}/edit',
    expectations: {
      E2eRole.guest: _auth[E2eRole.guest]!,
      E2eRole.outsider: E2eShowsAnyText(['Edit goal', 'Something went wrong']),
      E2eRole.member: E2eShowsAnyText(['Edit goal', 'Only the goal owner can edit this goal.']),
      E2eRole.owner: E2eShowsText('Edit goal'),
      E2eRole.admin: E2eRedirect('/admin'),
    },
  ),
  E2eScreen(
    id: 'reminder',
    path: '/goals/${SupabaseTestConfig.goalId}/reminder',
    expectations: {
      E2eRole.guest: _auth[E2eRole.guest]!,
      E2eRole.outsider: E2eShowsAnyText(['Log reminder', 'Something went wrong']),
      E2eRole.member: E2eShowsText('Log reminder'),
      E2eRole.owner: E2eShowsText('Log reminder'),
      E2eRole.admin: E2eRedirect('/admin'),
    },
  ),
  E2eScreen(
    id: 'goal_members',
    path: '/groups/${SupabaseTestConfig.groupId}/members',
    expectations: {
      E2eRole.guest: _auth[E2eRole.guest]!,
      E2eRole.outsider: E2eShowsAnyText(['Members', 'Something went wrong']),
      E2eRole.member: E2eShowsText('Members'),
      E2eRole.owner: E2eShowsText('Members'),
      E2eRole.admin: E2eRedirect('/admin'),
    },
  ),
];

/// Admin dashboard tabs (not separate routes; exercised after /admin loads).
const adminDashboardTabs = [
  'Overview',
  'Users',
  'Default data',
  'Feedback',
  'Crashes',
  'Configuration',
];
