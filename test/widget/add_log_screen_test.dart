import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tracketiv/features/goals/providers/goals_provider.dart';
import 'package:tracketiv/features/logs/presentation/add_log_screen.dart';
import 'package:tracketiv/features/logs/providers/logs_provider.dart';
import 'package:tracketiv/features/reminders/providers/reminder_provider.dart';
import 'package:tracketiv/shared/models/user_goal.dart';

import '../helpers/pump_app.dart';
import '../helpers/test_support.dart';

void main() {
  setUp(setUpTracketivTests);

  group('AddLogScreen', () {
    late FakeLogsRepository fakeLogs;
    late FakeReminderRepository fakeReminders;

    List<Override> buildOverrides({
      Future<UserGoal> Function(Ref ref, String goalId)? goalLoader,
    }) {
      return [
        logsRepositoryProvider.overrideWithValue(fakeLogs),
        reminderRepositoryProvider.overrideWithValue(fakeReminders),
        goalDetailProvider.overrideWith(
          (ref, goalId) => goalLoader?.call(ref, goalId) ?? Future.value(TestFixtures.weightGoal()),
        ),
      ];
    }

    setUp(() {
      fakeLogs = FakeLogsRepository();
      fakeReminders = FakeReminderRepository();
    });

    testWidgets('shows loading while goal is fetched', (tester) async {
      final delayedGoal = DelayedFuture<UserGoal>();

      await pumpTracketivWidget(
        tester,
        child: const AddLogScreen(goalId: TestFixtures.goalId),
        overrides: buildOverrides(
          goalLoader: (_, __) => delayedGoal.future,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      delayedGoal.complete(TestFixtures.weightGoal());
      await tester.pumpAndSettle();

      expect(find.text('Morning run'), findsOneWidget);
      expect(find.text('Save log'), findsOneWidget);
    });

    testWidgets('shows error when goal fetch fails', (tester) async {
      await pumpTracketivWidget(
        tester,
        child: const AddLogScreen(goalId: TestFixtures.goalId),
        overrides: buildOverrides(
          goalLoader: (_, __) => Future<UserGoal>.error(
            const PostgrestException(message: 'Goal not found', code: 'PGRST116'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('The requested item was not found.'), findsOneWidget);
    });

    testWidgets('creates log on save tap and navigates back', (tester) async {
      await pumpTracketivWidget(
        tester,
        child: const AddLogScreen(goalId: TestFixtures.goalId),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '3.2');
      await tapAndSettle(tester, findButtonByLabel('Save log'));
      await tester.pumpAndSettle();

      expect(fakeLogs.createLogCallCount, 1);
      expect(fakeLogs.createdLogs.single.value, 3.2);
    });

    testWidgets('shows loading on button while create is in flight', (tester) async {
      fakeLogs.createLogDelay = const Duration(milliseconds: 500);

      await pumpTracketivWidget(
        tester,
        child: const AddLogScreen(goalId: TestFixtures.goalId),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '2');
      await tapAndSettle(tester, findButtonByLabel('Save log'));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(fakeLogs.createLogCallCount, 1);
    });

    testWidgets('shows error when create fails', (tester) async {
      fakeLogs.createLogError = const PostgrestException(
        message: 'column logs.user_id does not exist',
        code: '42703',
      );

      await pumpTracketivWidget(
        tester,
        child: const AddLogScreen(goalId: TestFixtures.goalId),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '1');
      await tapAndSettle(tester, findButtonByLabel('Save log'));
      await tester.pumpAndSettle();

      expect(find.textContaining('user_id'), findsOneWidget);
      expect(fakeLogs.createLogCallCount, 1);
    });

    testWidgets('prompts to update when a log already exists today', (tester) async {
      fakeLogs.hasTodayLogResult = true;

      await pumpTracketivWidget(
        tester,
        child: const AddLogScreen(goalId: TestFixtures.goalId),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Update today\'s log'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '4');
      await tapAndSettle(tester, findButtonByLabel('Update today\'s log'));

      expect(find.text('Already logged today'), findsOneWidget);

      await tapAndSettle(tester, find.text('Update'));
      await tester.pumpAndSettle();

      expect(fakeLogs.createLogCallCount, 1);
    });
  });
}
