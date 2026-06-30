import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';
import 'package:tracketiv/core/offline/offline_cache.dart';
import 'package:tracketiv/core/offline/offline_fetch.dart';
import 'package:tracketiv/core/offline/offline_write_exception.dart';
import 'package:tracketiv/features/connections/data/connections_repository.dart';
import 'package:tracketiv/features/feed/data/feed_repository.dart';
import 'package:tracketiv/features/logs/data/logs_repository.dart';
import 'package:tracketiv/features/social/data/social_repository.dart';
import 'package:tracketiv/shared/models/log.dart';
import 'package:tracketiv/shared/utils/api_error_formatter.dart';

import 'controllable_connectivity.dart';
import 'real_http.dart';
import 'supabase_test_config.dart';
import 'supabase_test_harness.dart';

void main() {
  allowRealHttpInTests();

  late bool localSupabaseUp;
  late Directory cacheDir;
  late ControllableConnectivity connectivity;
  late LogsRepository logsRepo;
  late SocialRepository socialRepo;
  late ConnectionsRepository connectionsRepo;
  late FeedRepository feedRepo;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    allowRealHttpInTests();
    localSupabaseUp = await SupabaseTestHarness.isLocalStackRunning();
    if (!localSupabaseUp) return;
    await SupabaseTestHarness.client();
  });

  setUp(() async {
    allowRealHttpInTests();
    if (!localSupabaseUp) {
      fail(
        'Local Supabase is not running. '
        'Run: supabase start && supabase db reset '
        'or ./scripts/test-supabase.sh',
      );
    }
    cacheDir = await Directory.systemTemp.createTemp('tracketiv_integ_');
    connectivity = ControllableConnectivity(online: true);
    logsRepo = LogsRepository(
      await SupabaseTestHarness.client(),
      OfflineCache(directory: cacheDir),
      connectivity,
    );
    socialRepo = SocialRepository(
      await SupabaseTestHarness.client(),
      OfflineCache(directory: cacheDir),
      connectivity,
    );
    final client = await SupabaseTestHarness.client();
    connectionsRepo = ConnectionsRepository(client);
    feedRepo = FeedRepository(client, OfflineCache(directory: cacheDir));
    await SupabaseTestHarness.signOut();
  });

  tearDown(() async {
    if (!localSupabaseUp) return;
    await SupabaseTestHarness.signOut();
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  });

  group('LogsRepository (real Supabase)', () {
    test('reads seed logs for goal member', () async {
      await SupabaseTestHarness.signIn(
        email: SupabaseTestConfig.ownerEmail,
        password: SupabaseTestConfig.password,
      );

      final logs = await logsRepo.getLogsForGoal(SupabaseTestConfig.goalId);

      expect(logs, isNotEmpty);
      expect(logs.any((l) => l.note == 'Seed log from yesterday'), isTrue);
      expect(logs.first.authorId, isNotEmpty);
    });

    test('creates log successfully with author_id', () async {
      final user = await SupabaseTestHarness.signIn(
        email: SupabaseTestConfig.memberEmail,
        password: SupabaseTestConfig.password,
      );

      final uniqueDate = DateTime.utc(2099, 1, 15);
      await logsRepo.createLog(
        LogEntry(
          id: '',
          userGoalId: SupabaseTestConfig.goalId,
          authorId: user.id,
          logDate: uniqueDate,
          value: 6.1,
          note: 'integration create success',
          createdAt: DateTime.now(),
        ),
      );

      final mine = await logsRepo.getMyLogsForGoal(
        SupabaseTestConfig.goalId,
        user.id,
      );

      expect(
        mine.any(
          (l) =>
              l.note == 'integration create success' &&
              l.value == 6.1 &&
              l.logDateString == LogEntry.formatLogDate(uniqueDate),
        ),
        isTrue,
      );
    });

    test('updates same-day log instead of duplicate insert', () async {
      final user = await SupabaseTestHarness.signIn(
        email: SupabaseTestConfig.ownerEmail,
        password: SupabaseTestConfig.password,
      );

      final today = DateTime.now();
      await logsRepo.createLog(
        LogEntry(
          id: '',
          userGoalId: SupabaseTestConfig.goalId,
          authorId: user.id,
          logDate: today,
          value: 1.0,
          note: 'first today',
          createdAt: DateTime.now(),
        ),
      );
      await logsRepo.createLog(
        LogEntry(
          id: '',
          userGoalId: SupabaseTestConfig.goalId,
          authorId: user.id,
          logDate: today,
          value: 9.9,
          note: 'updated today',
          createdAt: DateTime.now(),
        ),
      );

      final todayLogs = (await logsRepo.getMyLogsForGoal(
        SupabaseTestConfig.goalId,
        user.id,
      )).where((l) => l.logDateString == LogEntry.formatLogDate(today));

      expect(todayLogs.length, 1);
      expect(todayLogs.first.value, 9.9);
      expect(todayLogs.first.note, 'updated today');
    });

    test('RLS failure: outsider cannot read goal logs', () async {
      await SupabaseTestHarness.signIn(
        email: SupabaseTestConfig.outsiderEmail,
        password: SupabaseTestConfig.password,
      );

      final logs = await logsRepo.getLogsForGoal(SupabaseTestConfig.goalId);
      expect(logs, isEmpty);
    });

    test('RLS failure: outsider cannot create log', () async {
      final user = await SupabaseTestHarness.signIn(
        email: SupabaseTestConfig.outsiderEmail,
        password: SupabaseTestConfig.password,
      );

      expect(
        () => logsRepo.createLog(
          LogEntry(
            id: '',
            userGoalId: SupabaseTestConfig.goalId,
            authorId: user.id,
            logDate: DateTime.utc(2099, 2, 1),
            value: 1,
            createdAt: DateTime.now(),
          ),
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('offline write guard throws OfflineWriteException', () async {
      final user = await SupabaseTestHarness.signIn(
        email: SupabaseTestConfig.ownerEmail,
        password: SupabaseTestConfig.password,
      );

      connectivity.online = false;

      expect(
        () => logsRepo.createLog(
          LogEntry(
            id: '',
            userGoalId: SupabaseTestConfig.goalId,
            authorId: user.id,
            logDate: DateTime.utc(2099, 3, 1),
            value: 2,
            createdAt: DateTime.now(),
          ),
        ),
        throwsA(isA<OfflineWriteException>()),
      );

      expect(
        OfflineWriteException.message.toUserMessage(),
        contains('offline'),
      );
    });
  });

  group('SocialRepository (real Supabase)', () {
    test('reads and creates comments', () async {
      final user = await SupabaseTestHarness.signIn(
        email: SupabaseTestConfig.memberEmail,
        password: SupabaseTestConfig.password,
      );

      final before = await socialRepo.getComments(SupabaseTestConfig.seedLogId);

      await socialRepo.addComment(
        logId: SupabaseTestConfig.seedLogId,
        authorId: user.id,
        body: 'integration comment ${DateTime.now().millisecondsSinceEpoch}',
      );

      final after = await socialRepo.getComments(SupabaseTestConfig.seedLogId);

      expect(after.length, greaterThan(before.length));
    });

    test('RLS failure: outsider cannot add comment', () async {
      final user = await SupabaseTestHarness.signIn(
        email: SupabaseTestConfig.outsiderEmail,
        password: SupabaseTestConfig.password,
      );

      expect(
        () => socialRepo.addComment(
          logId: SupabaseTestConfig.seedLogId,
          authorId: user.id,
          body: 'should be blocked',
        ),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  group('ConnectionsRepository (real Supabase)', () {
    test('friend request flow exposes owner logs in outsider feed', () async {
      await SupabaseTestHarness.signIn(
        email: SupabaseTestConfig.ownerEmail,
        password: SupabaseTestConfig.password,
      );

      final requestId = await connectionsRepo.sendFriendRequest(
        SupabaseTestConfig.outsiderId,
      );
      expect(requestId, isNotEmpty);

      await SupabaseTestHarness.signOut();
      await SupabaseTestHarness.signIn(
        email: SupabaseTestConfig.outsiderEmail,
        password: SupabaseTestConfig.password,
      );

      final requests = await connectionsRepo.listFriendRequests();
      final incoming = requests.where((r) => r.id == requestId);
      expect(incoming, hasLength(1));

      await connectionsRepo.respondFriendRequest(
        requestId: requestId,
        accept: true,
      );

      final feedBefore = await feedRepo.getFeed(limit: 100);
      final hasOwnerSeed = feedBefore.any(
        (item) => item.authorId == SupabaseTestConfig.ownerId,
      );
      expect(hasOwnerSeed, isTrue);

      await connectionsRepo.removeFriend(SupabaseTestConfig.ownerId);
    });
  });

  group('Offline cache sync (real cache + simulated network)', () {
    test('returns cached list when fetch fails with network error', () async {
      final cache = OfflineCache(directory: cacheDir);
      await cache.setJsonList('goal_logs_test', [
        {
          'id': 'cache-log-1',
          'user_goal_id': SupabaseTestConfig.goalId,
          'author_id': SupabaseTestConfig.ownerId,
          'log_date': '2024-01-01',
          'value': 1.5,
          'note': 'cached',
          'created_at': DateTime.utc(2024, 1, 1).toIso8601String(),
        },
      ]);

      final rows = await fetchListWithCache(
        cache: cache,
        cacheKey: 'goal_logs_test',
        fetchRows: () async => throw const SocketException('no network'),
        parse: LogEntry.fromJson,
      );

      expect(rows, hasLength(1));
      expect(rows.single.note, 'cached');
    });

    test('throws OfflineCacheMissException when offline and no cache', () async {
      final cache = OfflineCache(directory: cacheDir);

      expect(
        () => fetchListWithCache(
          cache: cache,
          cacheKey: 'missing_cache_key',
          emptyMessage: 'No cached logs for this goal.',
          fetchRows: () async => throw const SocketException('no network'),
          parse: LogEntry.fromJson,
        ),
        throwsA(
          isA<OfflineCacheMissException>().having(
            (e) => e.message,
            'message',
            'No cached logs for this goal.',
          ),
        ),
      );
    });

    test('primes cache from live Supabase then reads after simulated outage', () async {
      await SupabaseTestHarness.signIn(
        email: SupabaseTestConfig.ownerEmail,
        password: SupabaseTestConfig.password,
      );

      final live = await logsRepo.getLogsForGoal(SupabaseTestConfig.goalId);
      expect(live, isNotEmpty);

      final cached = await fetchListWithCache(
        cache: OfflineCache(directory: cacheDir),
        cacheKey: 'goal_logs_${SupabaseTestConfig.goalId}',
        fetchRows: () async => throw const SocketException('no network'),
        parse: LogEntry.fromJson,
      );

      expect(cached.length, live.length);
    });
  });

  group('API error formatting (real Postgrest errors)', () {
    test('maps permission denied to user-safe message', () async {
      final user = await SupabaseTestHarness.signIn(
        email: SupabaseTestConfig.outsiderEmail,
        password: SupabaseTestConfig.password,
      );

      try {
        await logsRepo.createLog(
          LogEntry(
            id: '',
            userGoalId: SupabaseTestConfig.goalId,
            authorId: user.id,
            logDate: DateTime.utc(2099, 12, 1),
            value: 1,
            createdAt: DateTime.now(),
          ),
        );
        fail('expected PostgrestException');
      } on PostgrestException catch (e) {
        final message = e.toUserMessage();
        expect(
          message == 'You do not have permission to do that.' ||
              message.contains('permission') ||
              !message.contains('PostgrestException'),
          isTrue,
        );
      }
    });
  });
}
