import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';
import '../integration/supabase_test_config.dart';
import '../integration/supabase_test_harness.dart';
import 'e2e_bootstrap.dart';
import 'e2e_http.dart';

void requireLocalSupabase(bool up) {
  if (!up) {
    fail(
      'Local Supabase is not running. '
      'Run: supabase start && supabase db reset '
      'or ./scripts/test-supabase.sh',
    );
  }
}

Future<void> e2eNavigate(
  WidgetTester tester,
  String path, {
  bool push = false,
}) async {
  await E2eBootstrap.navigateTo(tester, path, push: push);
}

Future<void> e2eTapButton(WidgetTester tester, String label) async {
  final button = findButtonByLabel(label);
  await e2eWaitFor(tester, button, reason: 'Button "$label"');
  await tapAndSettle(tester, button);
  await E2eBootstrap.pumpUntilSettled(tester);
}

Future<void> e2eWaitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    if (finder.evaluate().isNotEmpty) return;
  }
  fail(reason ?? 'Timed out waiting for $finder');
}

Future<bool> e2ePollUntil(Future<bool> Function() check, {int attempts = 50}) async {
  for (var i = 0; i < attempts; i++) {
    if (await check()) return true;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  return false;
}

Future<void> e2eRunAsync(WidgetTester tester, Future<void> Function() fn) async {
  await tester.runAsync(fn);
}

String todayLogDateString() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}

Future<void> clearTodayLogs({
  required String userId,
  required String goalId,
}) async {
  final client = await SupabaseTestHarness.client();
  await client
      .from('logs')
      .delete()
      .eq('user_goal_id', goalId)
      .eq('author_id', userId)
      .eq('log_date', todayLogDateString());
}

Future<bool> logExistsWithNote(String note) async {
  final client = await SupabaseTestHarness.client();
  final rows = await client.from('logs').select('id').eq('note', note).limit(1);
  return (rows as List).isNotEmpty;
}

Future<bool> commentExistsWithBody(String body) async {
  final client = await SupabaseTestHarness.client();
  final rows =
      await client.from('log_comments').select('id').eq('body', body).limit(1);
  return (rows as List).isNotEmpty;
}

Future<bool> groupExistsWithName(String name) async {
  final client = await SupabaseTestHarness.client();
  final rows = await client.from('groups').select('id').eq('name', name).limit(1);
  return (rows as List).isNotEmpty;
}

Future<void> clearReactionsForUser({
  required String logId,
  required String userId,
}) async {
  final client = await SupabaseTestHarness.client();
  await client
      .from('log_reactions')
      .delete()
      .eq('log_id', logId)
      .eq('user_id', userId);
}

Future<void> launchAs(
  WidgetTester tester,
  E2eRole role, {
  bool adminConsoleActive = false,
}) async {
  allowE2eHttpInTests();
  await E2eBootstrap.launchApp(
    tester,
    E2eLaunchOptions(
      role: role,
      adminConsoleActive: adminConsoleActive,
    ),
    useE2eHttp: true,
  );
}

Future<void> tearDownE2e(WidgetTester tester) async {
  allowE2eHttpInTests();
  await E2eBootstrap.tearDownApp(tester);
  await tester.pump(const Duration(milliseconds: 250));
}

String uniqueTag(String prefix) => '$prefix-${DateTime.now().microsecondsSinceEpoch}';

const goalLogPath = '/goals/${SupabaseTestConfig.goalId}/log';
const goalEditPath = '/goals/${SupabaseTestConfig.goalId}/edit';
const goalReminderPath = '/goals/${SupabaseTestConfig.goalId}/reminder';
const seedPostPath = '/feed/posts/${SupabaseTestConfig.seedLogId}';
