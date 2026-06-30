import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tracketiv/core/contracts/repository_contracts.dart';
import 'package:tracketiv/features/profile/data/profile_repository.dart';
import 'package:tracketiv/shared/models/log.dart';
import 'package:tracketiv/shared/models/log_comment.dart';
import 'package:tracketiv/shared/models/log_reaction.dart';
import 'package:tracketiv/shared/models/profile.dart';
import 'package:tracketiv/shared/models/profile_stats.dart';
import 'package:tracketiv/shared/models/reminder.dart';
import 'package:tracketiv/shared/models/user_goal.dart';

/// Shared ids and model instances for widget tests.
abstract final class TestFixtures {
  static const userId = 'user-test-1';
  static const goalId = 'goal-test-1';
  static const logId = 'log-test-1';

  static User testUser({
    String id = userId,
    String email = 'runner@tracketiv.test',
  }) {
    return User(
      id: id,
      email: email,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.utc(2024, 6, 1).toIso8601String(),
    );
  }

  static UserGoal weightGoal({String id = goalId}) {
    return UserGoal(
      id: id,
      ownerId: userId,
      title: 'Morning run',
      mode: 'solo',
      cadence: 'daily',
      metricType: 'distance',
      metricUnit: 'km',
      targetValue: 5,
      status: 'active',
      createdAt: DateTime.utc(2024, 6, 1),
    );
  }

  static Profile profile({String id = userId}) {
    return Profile(
      id: id,
      displayName: 'Test Runner',
      username: 'testrunner',
      bio: 'Training for a 5K',
      createdAt: DateTime.utc(2024, 6, 1),
    );
  }

  static ProfileStats profileStats() {
    return const ProfileStats(
      totalGoals: 2,
      activeGoals: 1,
      totalLogs: 12,
      logsThisWeek: 4,
      currentStreak: 3,
      totalGroups: 0,
      goals: [],
    );
  }

  static LogComment comment({
    String id = 'comment-1',
    String forLogId = logId,
    String body = 'Great progress!',
  }) {
    return LogComment(
      id: id,
      logId: forLogId,
      authorId: userId,
      body: body,
      createdAt: DateTime.utc(2024, 6, 2),
      authorProfile: const {'display_name': 'Test Runner'},
    );
  }

  static List<ReactionSummary> reactionSummaries({
    bool reactedByMe = false,
  }) {
    return [
      ReactionSummary(
        emojiType: 'fire',
        count: reactedByMe ? 1 : 2,
        reactedByMe: reactedByMe,
      ),
    ];
  }
}

/// Controllable fake for log create/read flows.
class FakeLogsRepository implements LogsRepositoryContract {
  FakeLogsRepository({
    this.hasTodayLogResult = false,
    this.createLogError,
    this.createLogDelay = Duration.zero,
  });

  bool hasTodayLogResult;
  Object? createLogError;
  Duration createLogDelay;

  final List<LogEntry> createdLogs = [];
  int createLogCallCount = 0;

  @override
  Future<void> createLog(LogEntry log) async {
    createLogCallCount++;
    await Future<void>.delayed(createLogDelay);
    if (createLogError != null) throw createLogError!;
    createdLogs.add(log);
  }

  @override
  Future<bool> hasTodayLog(String goalId, String userId) async {
    return hasTodayLogResult;
  }

  @override
  Future<List<LogEntry>> getLogsForGoal(String goalId) async => [];

  @override
  Future<List<LogEntry>> getMyLogsForGoal(String goalId, String userId) async =>
      [];

  @override
  Future<bool> everyoneLoggedToday(String goalId) async => false;
}

/// Controllable fake for comment/reaction flows.
class FakeSocialRepository implements SocialRepositoryContract {
  FakeSocialRepository({
    this.comments = const [],
    this.commentsError,
    this.commentsDelay = Duration.zero,
    this.addCommentError,
    this.addCommentDelay = Duration.zero,
    this.reactionSummaries = const [],
    this.reactionsDelay = Duration.zero,
    this.toggleReactionError,
  });

  List<LogComment> comments;
  Object? commentsError;
  Duration commentsDelay;
  Object? addCommentError;
  Duration addCommentDelay;
  List<ReactionSummary> reactionSummaries;
  Duration reactionsDelay;
  Object? toggleReactionError;

  final List<Map<String, String>> addedComments = [];
  final List<Map<String, String>> toggledReactions = [];

  @override
  Future<List<LogComment>> getComments(String logId) async {
    await Future<void>.delayed(commentsDelay);
    if (commentsError != null) throw commentsError!;
    return comments;
  }

  @override
  Future<void> addComment({
    required String logId,
    required String authorId,
    required String body,
  }) async {
    await Future<void>.delayed(addCommentDelay);
    if (addCommentError != null) throw addCommentError!;
    addedComments.add({
      'logId': logId,
      'authorId': authorId,
      'body': body,
    });
    comments = [
      ...comments,
      TestFixtures.comment(body: body),
    ];
  }

  @override
  Future<List<LogReaction>> getReactions(String logId) async => [];

  @override
  Future<List<ReactionSummary>> getReactionSummaries(
    String logId,
    String currentUserId,
  ) async {
    await Future<void>.delayed(reactionsDelay);
    return reactionSummaries;
  }

  @override
  Future<void> toggleReaction({
    required String logId,
    required String userId,
    required String emojiType,
  }) async {
    if (toggleReactionError != null) throw toggleReactionError!;
    toggledReactions.add({
      'logId': logId,
      'userId': userId,
      'emojiType': emojiType,
    });
    reactionSummaries = TestFixtures.reactionSummaries(
      reactedByMe: !reactionSummaries.any((r) => r.reactedByMe),
    );
  }
}

/// Controllable fake for profile read/update/upload flows.
class FakeProfileRepository implements ProfileRepositoryContract {
  FakeProfileRepository({
    this.profile,
    this.profileError,
    this.profileDelay = Duration.zero,
    this.updateError,
    this.updateDelay = Duration.zero,
    this.uploadError,
    this.uploadDelay = Duration.zero,
    this.uploadedUrl = 'https://cdn.test/avatar.png',
  });

  Profile? profile;
  Object? profileError;
  Duration profileDelay;
  Object? updateError;
  Duration updateDelay;
  Object? uploadError;
  Duration uploadDelay;
  String uploadedUrl;

  ProfileUpdate? lastUpdate;
  Uint8List? lastUploadBytes;
  int updateCallCount = 0;
  int uploadCallCount = 0;

  @override
  Future<Profile?> getProfile(String userId) async {
    await Future<void>.delayed(profileDelay);
    if (profileError != null) throw profileError!;
    return profile;
  }

  @override
  Future<ProfileStats?> getProfileStats(String userId) async {
    return TestFixtures.profileStats();
  }

  @override
  Future<Profile> updateProfile({
    required String userId,
    required ProfileUpdate update,
  }) async {
    updateCallCount++;
    await Future<void>.delayed(updateDelay);
    if (updateError != null) throw updateError!;
    lastUpdate = update;
    profile = Profile(
      id: userId,
      displayName: update.displayName ?? profile?.displayName,
      username: update.username ?? profile?.username,
      bio: update.clearBio ? null : (update.bio ?? profile?.bio),
      avatarUrl: update.avatarUrl ?? profile?.avatarUrl,
      createdAt: profile?.createdAt ?? DateTime.utc(2024, 6, 1),
    );
    return profile!;
  }

  @override
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    uploadCallCount++;
    await Future<void>.delayed(uploadDelay);
    if (uploadError != null) throw uploadError!;
    lastUploadBytes = bytes;
    return uploadedUrl;
  }
}

/// Controllable fake for feedback submit flow.
class FakeFeedbackRepository implements FeedbackRepositoryContract {
  FakeFeedbackRepository({
    this.submitError,
    this.submitDelay = Duration.zero,
    this.submittedId = 'feedback-1',
  });

  Object? submitError;
  Duration submitDelay;
  String submittedId;

  int submitCallCount = 0;
  String? lastType;
  String? lastMessage;

  @override
  Future<String> submitFeedback({
    required String type,
    required String message,
    String? contactEmail,
    String? displayName,
  }) async {
    submitCallCount++;
    lastType = type;
    lastMessage = message;
    await Future<void>.delayed(submitDelay);
    if (submitError != null) throw submitError!;
    return submittedId;
  }
}

/// Minimal fake — add-log only needs null reminder.
class FakeReminderRepository implements ReminderRepositoryContract {
  Reminder? reminder;

  @override
  Future<Reminder?> getReminder(String goalId, String userId) async => reminder;

  @override
  Future<List<Reminder>> getEnabledReminders(String userId) async => [];

  @override
  Future<Reminder> upsertReminder(Reminder reminder) async => reminder;

  @override
  Future<void> deleteReminder(String id) async {}
}

/// Delays a future until [complete] is called — useful for loading UI tests.
class DelayedFuture<T> {
  DelayedFuture() : _completer = Completer<T>();

  final Completer<T> _completer;

  Future<T> get future => _completer.future;

  void complete(T value) {
    if (!_completer.isCompleted) {
      _completer.complete(value);
    }
  }

  void completeError(Object error) {
    if (!_completer.isCompleted) {
      _completer.completeError(error);
    }
  }
}
