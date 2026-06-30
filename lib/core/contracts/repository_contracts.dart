import 'dart:typed_data';

import '../../features/profile/data/profile_repository.dart';
import '../../shared/models/log.dart';
import '../../shared/models/log_comment.dart';
import '../../shared/models/log_reaction.dart';
import '../../shared/models/profile.dart';
import '../../shared/models/profile_stats.dart';
import '../../shared/models/reminder.dart';

/// Abstractions for data access — enables widget tests with fakes/mocks.
abstract class LogsRepositoryContract {
  Future<List<LogEntry>> getLogsForGoal(String goalId);
  Future<List<LogEntry>> getMyLogsForGoal(String goalId, String userId);
  Future<bool> everyoneLoggedToday(String goalId);
  Future<void> createLog(LogEntry log);
  Future<bool> hasTodayLog(String goalId, String userId);
}

abstract class SocialRepositoryContract {
  Future<List<LogComment>> getComments(String logId);
  Future<void> addComment({
    required String logId,
    required String authorId,
    required String body,
  });
  Future<List<LogReaction>> getReactions(String logId);
  Future<List<ReactionSummary>> getReactionSummaries(
    String logId,
    String currentUserId,
  );
  Future<void> toggleReaction({
    required String logId,
    required String userId,
    required String emojiType,
  });
}

abstract class ProfileRepositoryContract {
  Future<Profile?> getProfile(String userId);
  Future<ProfileStats?> getProfileStats(String userId);
  Future<Profile> updateProfile({
    required String userId,
    required ProfileUpdate update,
  });
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileName,
  });
}

abstract class FeedbackRepositoryContract {
  Future<String> submitFeedback({
    required String type,
    required String message,
    String? contactEmail,
    String? displayName,
  });
}

abstract class ReminderRepositoryContract {
  Future<Reminder?> getReminder(String goalId, String userId);
  Future<List<Reminder>> getEnabledReminders(String userId);
  Future<Reminder> upsertReminder(Reminder reminder);
  Future<void> deleteReminder(String id);
}
