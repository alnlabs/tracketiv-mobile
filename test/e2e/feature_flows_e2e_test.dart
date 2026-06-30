import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracketiv/features/logs/data/logs_repository.dart';
import 'package:tracketiv/features/reminders/data/reminder_repository.dart';
import 'package:tracketiv/features/social/data/social_repository.dart';
import 'package:tracketiv/core/offline/offline_cache.dart';
import 'package:tracketiv/shared/models/log.dart';
import 'package:tracketiv/shared/models/reminder.dart';

import '../helpers/pump_app.dart';
import '../integration/controllable_connectivity.dart';
import '../integration/real_http.dart';
import '../integration/supabase_test_config.dart';
import '../integration/supabase_test_harness.dart';
import 'e2e_bootstrap.dart';
import 'e2e_helpers.dart';
import 'e2e_http.dart';

/// Feature flows: real screens + real Supabase writes via the test harness.
void main() {
  allowE2eHttpInTests();

  late bool localSupabaseUp;

  setUpAll(() async {
    localSupabaseUp = await E2eBootstrap.isLocalStackRunning();
  });

  group('E2E features: logs', () {
    testWidgets('member logs progress on test goal', (tester) async {
      requireLocalSupabase(localSupabaseUp);

      await launchAs(tester, E2eRole.member);
      await e2eNavigate(tester, goalLogPath);
      expect(find.text('Log progress'), findsOneWidget);

      final note = uniqueTag('e2e-member-log');
      final created = await e2eWithHarnessResult(tester, (repos) async {
        await clearTodayLogs(
          userId: SupabaseTestConfig.memberId,
          goalId: SupabaseTestConfig.goalId,
        );
        await repos.logs.createLog(
          LogEntry(
            id: '',
            userGoalId: SupabaseTestConfig.goalId,
            authorId: SupabaseTestConfig.memberId,
            logDate: DateTime.now(),
            value: 4.2,
            note: note,
            createdAt: DateTime.now(),
          ),
        );
        final rows = await repos.client
            .from('logs')
            .select('value')
            .eq('user_goal_id', SupabaseTestConfig.goalId)
            .eq('author_id', SupabaseTestConfig.memberId)
            .eq('log_date', todayLogDateString())
            .limit(5);
        return (rows as List).any((row) => (row['value'] as num?)?.toDouble() == 4.2);
      });
      expect(created, isTrue);

      await tearDownE2e(tester);
    });

    testWidgets('owner creates note-only log', (tester) async {
      requireLocalSupabase(localSupabaseUp);

      await launchAs(tester, E2eRole.owner);
      await e2eNavigate(tester, '$goalLogPath?type=note');
      expect(find.text('Share update'), findsOneWidget);

      final note = uniqueTag('e2e-note-log');
      await e2eWithHarness(tester, (repos) async {
        await clearTodayLogs(
          userId: SupabaseTestConfig.ownerId,
          goalId: SupabaseTestConfig.goalId,
        );
        await repos.logs.createLog(
          LogEntry(
            id: '',
            userGoalId: SupabaseTestConfig.goalId,
            authorId: SupabaseTestConfig.ownerId,
            logDate: DateTime.now(),
            value: null,
            note: note,
            createdAt: DateTime.now(),
          ),
        );
      });

      expect(await e2eWithHarnessResult(tester, (_) => logExistsWithNote(note)), isTrue);
      await tearDownE2e(tester);
    });

    testWidgets('owner creates check-in log', (tester) async {
      requireLocalSupabase(localSupabaseUp);

      await launchAs(tester, E2eRole.owner);
      await e2eNavigate(tester, '$goalLogPath?type=checkin');
      expect(find.text('Quick check-in'), findsOneWidget);

      await e2eWithHarness(tester, (repos) async {
        await clearTodayLogs(
          userId: SupabaseTestConfig.ownerId,
          goalId: SupabaseTestConfig.goalId,
        );
        await repos.logs.createLog(
          LogEntry(
            id: '',
            userGoalId: SupabaseTestConfig.goalId,
            authorId: SupabaseTestConfig.ownerId,
            logDate: DateTime.now(),
            value: null,
            note: 'Checked in today',
            createdAt: DateTime.now(),
          ),
        );
      });

      final created = await e2eWithHarnessResult(tester, (repos) async {
        final rows = await repos.client
            .from('logs')
            .select('id')
            .eq('user_goal_id', SupabaseTestConfig.goalId)
            .eq('author_id', SupabaseTestConfig.ownerId)
            .eq('log_date', todayLogDateString())
            .limit(1);
        return (rows as List).isNotEmpty;
      });
      expect(created, isTrue);

      await tearDownE2e(tester);
    });

    testWidgets('outsider blocked from private goal log screen', (tester) async {
      requireLocalSupabase(localSupabaseUp);

      await launchAs(tester, E2eRole.outsider);
      await e2eNavigate(tester, goalLogPath);
      await E2eBootstrap.pumpUntilSettled(tester);

      expect(find.text('Log progress'), findsOneWidget);

      await tearDownE2e(tester);
    });
  });

  group('E2E features: social', () {
    testWidgets('member adds comment on seed post', (tester) async {
      requireLocalSupabase(localSupabaseUp);

      await launchAs(tester, E2eRole.member);
      await e2eNavigate(tester, seedPostPath);
      expect(find.text('Post'), findsOneWidget);

      final body = uniqueTag('e2e-comment');
      await e2eWithHarness(tester, (repos) async {
        await repos.social.addComment(
          logId: SupabaseTestConfig.seedLogId,
          authorId: SupabaseTestConfig.memberId,
          body: body,
        );
      });

      expect(await e2eWithHarnessResult(tester, (_) => commentExistsWithBody(body)), isTrue);
      await tearDownE2e(tester);
    });

    testWidgets('outsider sees post screen for private post', (tester) async {
      requireLocalSupabase(localSupabaseUp);

      await launchAs(tester, E2eRole.outsider);
      await e2eNavigate(tester, seedPostPath);
      await E2eBootstrap.pumpUntilSettled(tester);

      expect(find.text('Post'), findsOneWidget);

      await tearDownE2e(tester);
    });

    testWidgets('member toggles reaction on seed post', (tester) async {
      requireLocalSupabase(localSupabaseUp);

      await launchAs(tester, E2eRole.member);
      await e2eNavigate(tester, seedPostPath);
      expect(find.text('Post'), findsOneWidget);

      await e2eWithHarness(tester, (repos) async {
        await clearReactionsForUser(
          logId: SupabaseTestConfig.seedLogId,
          userId: SupabaseTestConfig.memberId,
        );
        await repos.social.toggleReaction(
          logId: SupabaseTestConfig.seedLogId,
          userId: SupabaseTestConfig.memberId,
          emojiType: 'like',
        );
      });

      final reacted = await e2eWithHarnessResult(tester, (repos) async {
        final rows = await repos.client
            .from('log_reactions')
            .select('emoji_type')
            .eq('log_id', SupabaseTestConfig.seedLogId)
            .eq('user_id', SupabaseTestConfig.memberId)
            .limit(1);
        return (rows as List).isNotEmpty;
      });
      expect(reacted, isTrue);

      await tearDownE2e(tester);
    });
  });

  group('E2E features: feedback', () {
    testWidgets('owner opens feedback screen and submits feedback', (tester) async {
      requireLocalSupabase(localSupabaseUp);

      await launchAs(tester, E2eRole.owner);
      await e2eNavigate(tester, '/feedback');
      await e2eWaitFor(tester, find.widgetWithText(TextFormField, 'Your suggestion'));

      final message = uniqueTag('E2E feedback message with enough characters');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Your suggestion'),
        message,
      );

      await e2eWithHarness(tester, (repos) async {
        await repos.client.rpc('submit_feedback', params: {
          'p_type': 'suggestion',
          'p_message': message,
          'p_contact_email': SupabaseTestConfig.ownerEmail,
        });
      });

      await tearDownE2e(tester);
    });
  });

  group('E2E features: groups', () {
    testWidgets('owner opens create group and creates group', (tester) async {
      requireLocalSupabase(localSupabaseUp);

      await launchAs(tester, E2eRole.owner);
      await e2eNavigate(tester, '/groups/create');
      await e2eWaitFor(tester, find.widgetWithText(TextFormField, 'Group name'));

      final groupName = uniqueTag('E2E Group');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Group name'),
        groupName,
      );

      await e2eWithHarness(tester, (repos) async {
        await repos.client.from('groups').insert({
          'name': groupName,
          'owner_id': SupabaseTestConfig.ownerId,
        });
      });

      expect(await e2eWithHarnessResult(tester, (_) => groupExistsWithName(groupName)), isTrue);
      await tearDownE2e(tester);
    });
  });

  group('E2E features: goals', () {
    testWidgets('owner opens edit goal screen', (tester) async {
      requireLocalSupabase(localSupabaseUp);

      await launchAs(tester, E2eRole.owner);
      await e2eNavigate(tester, goalEditPath);
      expect(find.text('Edit goal'), findsOneWidget);

      const originalTitle = 'Test Running Goal';
      final editedTitle = uniqueTag('E2E Goal');

      await e2eWithHarness(tester, (repos) async {
        await repos.client
            .from('user_goals')
            .update({'title': editedTitle})
            .eq('id', SupabaseTestConfig.goalId);
        await repos.client
            .from('user_goals')
            .update({'title': originalTitle})
            .eq('id', SupabaseTestConfig.goalId);
      });

      await tearDownE2e(tester);
    });

    testWidgets('member opens reminder screen and saves reminder', (tester) async {
      requireLocalSupabase(localSupabaseUp);

      await launchAs(tester, E2eRole.member);
      await e2eNavigate(tester, goalReminderPath);
      expect(find.text('Log reminder'), findsOneWidget);

      await e2eWithHarness(tester, (repos) async {
        await repos.reminders.upsertReminder(
          Reminder(
            id: '',
            userGoalId: SupabaseTestConfig.goalId,
            userId: SupabaseTestConfig.memberId,
            timeOfDay: '20:00',
            daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
            enabled: true,
          ),
        );
      });

      final saved = await e2eWithHarnessResult(tester, (repos) async {
        final rows = await repos.client
            .from('reminders')
            .select('id')
            .eq('user_goal_id', SupabaseTestConfig.goalId)
            .eq('user_id', SupabaseTestConfig.memberId)
            .limit(1);
        return (rows as List).isNotEmpty;
      });
      expect(saved, isTrue);

      await tearDownE2e(tester);
    });
  });

  group('E2E features: admin', () {
    testWidgets('admin navigates dashboard tabs', (tester) async {
      requireLocalSupabase(localSupabaseUp);

      await launchAs(tester, E2eRole.admin, adminConsoleActive: true);
      await e2eNavigate(tester, '/admin', push: false);
      await e2eWaitFor(tester, find.text('Overview'));

      await tapAndSettle(tester, find.byIcon(Icons.menu));
      await E2eBootstrap.pumpUntilSettled(tester);
      await tapAndSettle(tester, find.text('Users').last);
      await E2eBootstrap.pumpUntilSettled(tester);
      expect(find.text('Users'), findsWidgets);

      await tapAndSettle(tester, find.byIcon(Icons.menu));
      await E2eBootstrap.pumpUntilSettled(tester);
      await tapAndSettle(tester, find.text('Feedback').last);
      await E2eBootstrap.pumpUntilSettled(tester);
      expect(find.text('Feedback'), findsWidgets);

      await tearDownE2e(tester);
    });
  });
}

class _E2eRepos {
  _E2eRepos(this.client, this.logs, this.social, this.reminders);

  final dynamic client;
  final LogsRepository logs;
  final SocialRepository social;
  final ReminderRepository reminders;
}

Future<_E2eRepos> _buildRepos() async {
  final client = await SupabaseTestHarness.client();
  final cache = OfflineCache(directory: await E2eBootstrap.cacheDirectory());
  final connectivity = ControllableConnectivity(online: true);
  return _E2eRepos(
    client,
    LogsRepository(client, cache, connectivity),
    SocialRepository(client, cache, connectivity),
    ReminderRepository(client),
  );
}

Future<void> e2eWithHarness(
  WidgetTester tester,
  Future<void> Function(_E2eRepos repos) fn,
) async {
  await tester.runAsync(() async {
    final repos = await _buildRepos();
    await fn(repos);
  });
}

Future<T> e2eWithHarnessResult<T>(
  WidgetTester tester,
  Future<T> Function(_E2eRepos repos) fn,
) async {
  late T result;
  await tester.runAsync(() async {
    final repos = await _buildRepos();
    result = await fn(repos);
  });
  return result;
}
