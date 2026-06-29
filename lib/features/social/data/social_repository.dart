import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/models/log_comment.dart';
import '../../../shared/models/log_reaction.dart';

class SocialRepository {
  SocialRepository(this._client);

  final SupabaseClient _client;

  Future<List<LogComment>> getComments(String logId) async {
    final data = await _client
        .from('log_comments')
        .select('*, profiles(display_name, avatar_url)')
        .eq('log_id', logId)
        .order('created_at');
    return (data as List).map((e) => LogComment.fromJson(e)).toList();
  }

  Future<LogComment> addComment({
    required String logId,
    required String authorId,
    required String body,
  }) async {
    final data = await _client
        .from('log_comments')
        .insert({'log_id': logId, 'author_id': authorId, 'body': body})
        .select('*, profiles(display_name, avatar_url)')
        .single();
    return LogComment.fromJson(data);
  }

  Future<List<LogReaction>> getReactions(String logId) async {
    final data = await _client
        .from('log_reactions')
        .select()
        .eq('log_id', logId);
    return (data as List).map((e) => LogReaction.fromJson(e)).toList();
  }

  Future<List<ReactionSummary>> getReactionSummaries(
    String logId,
    String currentUserId,
  ) async {
    final reactions = await getReactions(logId);
    return AppConstants.reactionTypes.map((type) {
      final ofType = reactions.where((r) => r.emojiType == type).toList();
      return ReactionSummary(
        emojiType: type,
        count: ofType.length,
        reactedByMe: ofType.any((r) => r.userId == currentUserId),
      );
    }).toList();
  }

  Future<void> toggleReaction({
    required String logId,
    required String userId,
    required String emojiType,
  }) async {
    final existing = await _client
        .from('log_reactions')
        .select()
        .eq('log_id', logId)
        .eq('user_id', userId)
        .eq('emoji_type', emojiType)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('log_reactions')
          .delete()
          .eq('id', existing['id']);
    } else {
      await _client.from('log_reactions').insert({
        'log_id': logId,
        'user_id': userId,
        'emoji_type': emojiType,
      });
    }
  }
}
